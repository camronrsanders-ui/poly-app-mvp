import {
  FieldValue,
  getFirestore,
} from 'firebase-admin/firestore';
import {onDocumentUpdated} from 'firebase-functions/v2/firestore';

function isDeletionPending(
  snapshot: FirebaseFirestore.DocumentSnapshot,
): boolean {
  return snapshot.exists &&
    snapshot.get('accountStatus') === 'paused' &&
    snapshot.get('deletionRequestedAt') != null;
}

async function queryCircleScopedDocs(
  collection: 'circle_memberships' | 'circle_invites',
  circleIds: string[],
): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> {
  const db = getFirestore();
  const docs: FirebaseFirestore.QueryDocumentSnapshot[] = [];

  for (let offset = 0; offset < circleIds.length; offset += 10) {
    const chunk = circleIds.slice(offset, offset + 10);
    if (chunk.length === 0) continue;

    const snapshot = await db
      .collection(collection)
      .where('circleId', 'in', chunk)
      .get();

    docs.push(...snapshot.docs);
  }

  return docs;
}

async function removeMembershipAndAdjustCountAtomically(
  membershipRef: FirebaseFirestore.DocumentReference,
): Promise<void> {
  const db = getFirestore();

  await db.runTransaction(async (transaction) => {
    const membership = await transaction.get(membershipRef);
    if (!membership.exists) return;

    const circleId = String(membership.get('circleId') ?? '').trim();
    const active = membership.get('status') === 'active';
    const role = String(membership.get('role') ?? 'member');

    if (!active || role === 'owner' || !circleId) {
      transaction.delete(membershipRef);
      return;
    }

    const circleRef = db.collection('circles').doc(circleId);
    const circle = await transaction.get(circleRef);

    transaction.delete(membershipRef);

    if (!circle.exists) return;

    // The membership deletion and persisted count adjustment must commit
    // together. Otherwise a partial BulkWriter failure could leave a stale
    // memberCount or cause a later retry to decrement the same member twice.
    transaction.update(circleRef, {
      memberCount: FieldValue.increment(-1),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

/**
 * Circle data is lifecycle-coupled to account deletion.
 *
 * The main deletion callable pauses the account before destructive cleanup.
 * Listening for that durable state gives Circle cleanup a retriable path even
 * if a later Storage/Auth/tombstone step needs another deletion attempt.
 *
 * There is intentionally no ownership transfer policy yet. If a deleting
 * member owns a Circle, the Circle and its memberships/invitations are removed.
 * A non-owner deletion removes only that person's membership/invitations and
 * decrements the persisted member count for an active membership.
 */
export const cleanupCircleDataForDeletingAccount = onDocumentUpdated(
  {
    document: 'users/{uid}',
    maxInstances: 10,
  },
  async (event) => {
    const after = event.data?.after;
    const uid = String(event.params.uid ?? '').trim();

    if (!uid || !after || !isDeletionPending(after)) return;

    // Run on every update while deletion is pending. The cleanup is idempotent,
    // so a later retry/minimal-marker update can finish work left by a transient
    // failure without requiring the account to transition out of paused state.
    const db = getFirestore();

    const [
      ownedCircles,
      ownMemberships,
      incomingInvites,
      outgoingInvites,
    ] = await Promise.all([
      db.collection('circles').where('ownerUid', '==', uid).get(),
      db.collection('circle_memberships').where('uid', '==', uid).get(),
      db.collection('circle_invites').where('inviteeUid', '==', uid).get(),
      db.collection('circle_invites').where('inviterUid', '==', uid).get(),
    ]);

    const ownedCircleIds = ownedCircles.docs.map((doc) => doc.id);
    const ownedCircleIdSet = new Set(ownedCircleIds);

    const [ownedMemberships, ownedInvites] = await Promise.all([
      queryCircleScopedDocs('circle_memberships', ownedCircleIds),
      queryCircleScopedDocs('circle_invites', ownedCircleIds),
    ]);

    const atomicallyRemovedMembershipPaths = new Set<string>();

    // Active non-owner memberships in Circles that survive this account
    // deletion require an atomic membership-delete + count-decrement pair.
    // Process them before the idempotent bulk deletion below.
    for (const membership of ownMemberships.docs) {
      const circleId = String(membership.get('circleId') ?? '').trim();
      const active = membership.get('status') === 'active';
      const role = String(membership.get('role') ?? 'member');

      if (
        !active ||
        role === 'owner' ||
        !circleId ||
        ownedCircleIdSet.has(circleId)
      ) {
        continue;
      }

      await removeMembershipAndAdjustCountAtomically(membership.ref);
      atomicallyRemovedMembershipPaths.add(membership.ref.path);
    }

    const writer = db.bulkWriter();
    const deletedPaths = new Set<string>();

    const deleteDoc = (doc: FirebaseFirestore.DocumentSnapshot) => {
      if (
        !doc.exists ||
        deletedPaths.has(doc.ref.path) ||
        atomicallyRemovedMembershipPaths.has(doc.ref.path)
      ) {
        return;
      }
      deletedPaths.add(doc.ref.path);
      writer.delete(doc.ref);
    };

    for (const circle of ownedCircles.docs) deleteDoc(circle);
    for (const membership of ownedMemberships) deleteDoc(membership);
    for (const invite of ownedInvites) deleteDoc(invite);
    for (const invite of incomingInvites.docs) deleteDoc(invite);
    for (const invite of outgoingInvites.docs) deleteDoc(invite);
    for (const membership of ownMemberships.docs) deleteDoc(membership);

    for (const action of [
      'create',
      'invite',
      'respond',
      'leave',
      'list',
    ]) {
      writer.delete(
        db.collection('_rate_limits').doc(`circle_${action}_${uid}`),
      );
    }

    await writer.close();
  },
);
