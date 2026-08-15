import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {assertActiveCompliantMember} from './account_compliance';

const allowedReportReasons = new Set([
  'harassment',
  'threats_violence',
  'child_safety',
  'sexual_content',
  'fake_profile',
  'hate_speech',
  'misrepresentation',
  'spam',
  'nonconsensual_content',
  'other',
]);

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

function timestampMillis(value: unknown): number | null {
  const candidate = value as {toMillis?: () => number} | null | undefined;
  return candidate?.toMillis?.() ?? null;
}

async function assertActive(uid: string): Promise<void> {
  await assertActiveCompliantMember(getFirestore(), uid);
}

async function enforceRateLimit(uid: string, action: string, max = 20, windowMs = 60_000): Promise<void> {
  const db = getFirestore();
  const ref = db.collection('_rate_limits').doc(`${action}_${uid}`);
  const now = Date.now();

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

export const submitReport = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const db = getFirestore();
    const reporterUid = requireUid(request.auth);
    const reportedUid = requireTargetUid(request.data?.reportedUid, reporterUid);
    const reason = String(request.data?.reason ?? '').trim();
    const details = String(request.data?.details ?? '').trim();

    if (!allowedReportReasons.has(reason)) {
      throw new HttpsError('invalid-argument', 'Invalid report reason.');
    }
    if (details.length > 2000) {
      throw new HttpsError('invalid-argument', 'Report details are too long.');
    }

    await Promise.all([
      assertActive(reporterUid),
      enforceRateLimit(reporterUid, 'report', 8, 60 * 60_000),
    ]);

    const target = await db.collection('users').doc(reportedUid).get();
    if (!target.exists) throw new HttpsError('not-found', 'Reported account was not found.');

    const ref = db.collection('reports').doc();
    await ref.set({
      reportId: ref.id,
      reporterUid,
      reportedUid,
      reason,
      details,
      createdAt: FieldValue.serverTimestamp(),
      status: 'open',
    });

    return {submitted: true, reportId: ref.id};
  },
);

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
          endedAt: FieldValue.serverTimestamp(),
          endedReason: 'blocked',
        }, {merge: true});
      }
    });

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

    const blockRef = db.collection('blocks').doc(`${blockerUid}_${blockedUid}`);
    const block = await blockRef.get();
    if (!block.exists || block.get('blockerUid') !== blockerUid || block.get('blockedUid') !== blockedUid) {
      throw new HttpsError('not-found', 'Block not found.');
    }

    // A previous block may have persisted while its secondary private-access
    // cleanup failed. Revoke again before removing the block so an unblock can
    // never make a stale grant usable without fresh consent.
    await revokePrivateAccessBetween(blockerUid, blockedUid, 'unblocked_after_block');
    await blockRef.delete();
    return {blocked: false};
  },
);

export const listMyBlocks = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const db = getFirestore();
    const uid = requireUid(request.auth);
    await Promise.all([
      assertActive(uid),
      enforceRateLimit(uid, 'block_list', 60, 60_000),
    ]);

    const snapshot = await db.collection('blocks')
      .where('blockerUid', '==', uid)
      .limit(200)
      .get();
    if (snapshot.empty) return {blocks: []};

    const blockedUids = snapshot.docs
      .map((doc) => String(doc.get('blockedUid') ?? '').trim())
      .filter((blockedUid) => blockedUid.length > 0 && blockedUid !== uid);
    const uniqueUids = [...new Set(blockedUids)].slice(0, 200);
    const profileRefs = uniqueUids.map((blockedUid) => db.collection('profiles').doc(blockedUid));
    const profiles = profileRefs.length ? await db.getAll(...profileRefs) : [];
    const names = new Map(profiles.map((profile) => {
      const raw = profile.exists ? profile.get('displayName') : null;
      const displayName = typeof raw === 'string' && raw.trim()
        ? raw.trim().slice(0, 80)
        : 'Blocked member';
      return [profile.id, displayName];
    }));

    const blocks = snapshot.docs
      .map((doc) => {
        const blockedUid = String(doc.get('blockedUid') ?? '').trim();
        if (!blockedUid || blockedUid === uid) return null;
        return {
          blockedUid,
          displayName: names.get(blockedUid) ?? 'Blocked member',
          createdAtMs: timestampMillis(doc.get('createdAt')),
        };
      })
      .filter((block): block is NonNullable<typeof block> => block !== null);
    blocks.sort((a, b) => (b.createdAtMs ?? 0) - (a.createdAtMs ?? 0));
    return {blocks};
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

      // Always clear stale reciprocal interest, but preserve the original end
      // metadata when the connection was already closed by an earlier action.
      tx.delete(outgoingLikeRef);
      tx.delete(incomingLikeRef);
      if (match.get('active') !== true) return;

      tx.set(matchRef, {
        active: false,
        endedAt: FieldValue.serverTimestamp(),
        endedByUid: uid,
        endedReason: 'unmatched',
      }, {merge: true});

      if (conversation.exists && conversation.get('active') === true) {
        tx.set(conversationRef, {
          active: false,
          endedAt: FieldValue.serverTimestamp(),
          endedReason: 'unmatched',
        }, {merge: true});
      }
    });

    await revokePrivateAccessBetween(uid, otherUid, 'unmatched');
    return {ended: true};
  },
);
