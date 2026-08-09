import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

function requireTargetUid(raw: unknown, currentUid: string): string {
  const uid = String(raw ?? '').trim();
  if (!uid || uid.length > 128 || uid === currentUid) {
    throw new HttpsError('invalid-argument', 'Invalid target user.');
  }
  return uid;
}

function pairId(a: string, b: string): string {
  return [a, b].sort().join('_');
}

async function assertActive(uid: string): Promise<void> {
  const db = getFirestore();
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists || snap.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Account is not active.');
  }
}

async function enforceRateLimit(uid: string, action: string): Promise<void> {
  const db = getFirestore();
  const ref = db.collection('_rate_limits').doc(`${action}_${uid}`);
  const now = Date.now();
  const windowMs = 60_000;
  const max = 20;

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const start = snap.get('windowStart')?.toMillis?.() ?? 0;
    const count = Number(snap.get('count') ?? 0);
    if (!snap.exists || now - start >= windowMs) {
      tx.set(ref, {
        uid,
        action,
        count: 1,
        windowStart: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }
    if (count >= max) {
      throw new HttpsError('resource-exhausted', 'Please wait a moment and try again.');
    }
    tx.update(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()});
  });
}

async function revokePrivateAccessBetween(a: string, b: string, reason: string): Promise<void> {
  const db = getFirestore();
  const [grantsAB, grantsBA, requestsAB, requestsBA] = await Promise.all([
    db.collection('private_media_grants').where('ownerUid', '==', a).where('recipientUid', '==', b).get(),
    db.collection('private_media_grants').where('ownerUid', '==', b).where('recipientUid', '==', a).get(),
    db.collection('private_media_requests').where('requesterUid', '==', a).where('recipientUid', '==', b).get(),
    db.collection('private_media_requests').where('requesterUid', '==', b).where('recipientUid', '==', a).get(),
  ]);

  const writer = db.bulkWriter();
  for (const doc of [...grantsAB.docs, ...grantsBA.docs]) {
    writer.set(doc.ref, {
      active: false,
      revokedAt: FieldValue.serverTimestamp(),
      revokedReason: reason,
    }, {merge: true});
  }
  for (const doc of [...requestsAB.docs, ...requestsBA.docs]) {
    writer.set(doc.ref, {
      status: 'cancelled',
      cancelledAt: FieldValue.serverTimestamp(),
      cancelledReason: reason,
    }, {merge: true});
  }
  await writer.close();
}

export const blockUser = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const db = getFirestore();
    const blockerUid = requireUid(request.auth);
    const blockedUid = requireTargetUid(request.data?.blockedUid, blockerUid);
    await Promise.all([assertActive(blockerUid), enforceRateLimit(blockerUid, 'block')]);

    const blockRef = db.collection('blocks').doc(`${blockerUid}_${blockedUid}`);
    const pair = pairId(blockerUid, blockedUid);
    const matchRef = db.collection('matches').doc(pair);
    const conversationRef = db.collection('conversations').doc(pair);
    const outgoingLikeRef = db.collection('likes').doc(`${blockerUid}_${blockedUid}`);
    const incomingLikeRef = db.collection('likes').doc(`${blockedUid}_${blockerUid}`);

    await db.runTransaction(async (tx) => {
      const [block, match, conversation] = await Promise.all([
        tx.get(blockRef),
        tx.get(matchRef),
        tx.get(conversationRef),
      ]);

      if (!block.exists) {
        tx.create(blockRef, {
          blockerUid,
          blockedUid,
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      tx.delete(outgoingLikeRef);
      tx.delete(incomingLikeRef);

      if (match.exists && match.get('active') === true) {
        tx.set(matchRef, {
          active: false,
          endedAt: FieldValue.serverTimestamp(),
          endedReason: 'blocked',
        }, {merge: true});
      }

      if (conversation.exists && conversation.get('active') === true) {
        tx.set(conversationRef, {
          active: false,
          lastMessageAt: FieldValue.serverTimestamp(),
          endedReason: 'blocked',
        }, {merge: true});
      }
    });

    // Private-media access is revoked independently of cleanup timing. The
    // access function also re-checks blocks, so a stale grant cannot bypass a block.
    await revokePrivateAccessBetween(blockerUid, blockedUid, 'blocked');
    return {blocked: true};
  },
);

export const unblockUser = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const db = getFirestore();
    const blockerUid = requireUid(request.auth);
    const blockedUid = requireTargetUid(request.data?.blockedUid, blockerUid);
    await Promise.all([assertActive(blockerUid), enforceRateLimit(blockerUid, 'unblock')]);

    await db.collection('blocks').doc(`${blockerUid}_${blockedUid}`).delete();

    // Intentionally do not restore likes, matches, conversations, or grants.
    // Unblocking only removes the block; both people must form a new connection.
    return {blocked: false};
  },
);

export const endConnection = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const db = getFirestore();
    const uid = requireUid(request.auth);
    const otherUid = requireTargetUid(request.data?.otherUid, uid);
    await Promise.all([assertActive(uid), enforceRateLimit(uid, 'unmatch')]);

    const pair = pairId(uid, otherUid);
    const matchRef = db.collection('matches').doc(pair);
    const conversationRef = db.collection('conversations').doc(pair);
    const outgoingLikeRef = db.collection('likes').doc(`${uid}_${otherUid}`);
    const incomingLikeRef = db.collection('likes').doc(`${otherUid}_${uid}`);

    await db.runTransaction(async (tx) => {
      const [match, conversation] = await Promise.all([
        tx.get(matchRef),
        tx.get(conversationRef),
      ]);

      if (!match.exists || (match.get('userAUid') !== uid && match.get('userBUid') !== uid)) {
        throw new HttpsError('not-found', 'Connection not found.');
      }

      tx.delete(outgoingLikeRef);
      tx.delete(incomingLikeRef);
      tx.set(matchRef, {
        active: false,
        endedAt: FieldValue.serverTimestamp(),
        endedByUid: uid,
        endedReason: 'unmatched',
      }, {merge: true});

      if (conversation.exists) {
        tx.set(conversationRef, {
          active: false,
          lastMessageAt: FieldValue.serverTimestamp(),
          endedReason: 'unmatched',
        }, {merge: true});
      }
    });

    await revokePrivateAccessBetween(uid, otherUid, 'unmatched');
    return {ended: true};
  },
);
