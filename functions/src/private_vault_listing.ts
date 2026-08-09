import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

const db = getFirestore();

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

async function assertActive(uid: string): Promise<void> {
  const user = await db.collection('users').doc(uid).get();
  if (!user.exists || user.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Account is not active.');
  }
}

async function consumeRateLimit(uid: string, action: string, max = 60): Promise<void> {
  const ref = db.collection('_rate_limits').doc(`${action}_${uid}`);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const start = Number(snap.get('windowStartMs') ?? 0);
    const count = Number(snap.get('count') ?? 0);
    if (!snap.exists || now - start >= 60_000) {
      tx.set(ref, {
        uid,
        action,
        windowStartMs: now,
        count: 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }
    if (count >= max) {
      throw new HttpsError('resource-exhausted', 'Too many requests. Try again later.');
    }
    tx.set(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

function pairId(a: string, b: string): string {
  return [a, b].sort().join('_');
}

async function pairIsEligible(a: string, b: string): Promise<boolean> {
  const [userA, userB, blockAB, blockBA, match] = await Promise.all([
    db.collection('users').doc(a).get(),
    db.collection('users').doc(b).get(),
    db.collection('blocks').doc(`${a}_${b}`).get(),
    db.collection('blocks').doc(`${b}_${a}`).get(),
    db.collection('matches').doc(pairId(a, b)).get(),
  ]);
  return userA.exists
    && userA.get('accountStatus') === 'active'
    && userB.exists
    && userB.get('accountStatus') === 'active'
    && !blockAB.exists
    && !blockBA.exists
    && match.exists
    && match.get('active') === true;
}

async function displayName(uid: string): Promise<string> {
  const profile = await db.collection('profiles').doc(uid).get();
  return profile.exists ? String(profile.get('displayName') ?? 'Connection').slice(0, 80) : 'Connection';
}

function millis(value: unknown): number | null {
  if (value && typeof (value as {toMillis?: unknown}).toMillis === 'function') {
    return (value as {toMillis: () => number}).toMillis();
  }
  return null;
}

export const listMyPrivateMediaRequests = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const uid = requireUid(request.auth);
    await Promise.all([
      assertActive(uid),
      consumeRateLimit(uid, 'private_media_request_list'),
    ]);

    const [outgoing, incoming] = await Promise.all([
      db.collection('private_media_requests').where('requesterUid', '==', uid).limit(100).get(),
      db.collection('private_media_requests').where('recipientUid', '==', uid).limit(100).get(),
    ]);

    const items: FirebaseFirestore.DocumentData[] = [];
    for (const snap of [...outgoing.docs, ...incoming.docs]) {
      const requesterUid = String(snap.get('requesterUid') ?? '');
      const recipientUid = String(snap.get('recipientUid') ?? '');
      if (!requesterUid || !recipientUid) continue;
      const otherUid = requesterUid === uid ? recipientUid : requesterUid;
      if (!(await pairIsEligible(uid, otherUid))) continue;

      items.push({
        requestId: snap.id,
        direction: requesterUid === uid ? 'outgoing' : 'incoming',
        otherUid,
        otherDisplayName: await displayName(otherUid),
        status: String(snap.get('status') ?? 'unknown'),
        createdAtMs: millis(snap.get('createdAt')),
        respondedAtMs: millis(snap.get('respondedAt')),
        cancelledAtMs: millis(snap.get('cancelledAt')),
      });
    }
    return {requests: items};
  },
);

export const listMyPrivateMediaShares = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const ownerUid = requireUid(request.auth);
    await Promise.all([
      assertActive(ownerUid),
      consumeRateLimit(ownerUid, 'private_media_share_list'),
    ]);

    const grants = await db.collection('private_media_grants')
      .where('ownerUid', '==', ownerUid)
      .limit(250)
      .get();
    const shares: FirebaseFirestore.DocumentData[] = [];
    for (const grant of grants.docs) {
      if (grant.get('active') !== true) continue;
      const recipientUid = String(grant.get('recipientUid') ?? '');
      const mediaId = String(grant.get('mediaId') ?? '');
      if (!recipientUid || !mediaId || !(await pairIsEligible(ownerUid, recipientUid))) continue;
      shares.push({
        grantId: grant.id,
        mediaId,
        recipientUid,
        recipientDisplayName: await displayName(recipientUid),
        createdAtMs: millis(grant.get('createdAt')),
      });
    }
    return {shares};
  },
);

export const listMyPrivateMediaInbox = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const recipientUid = requireUid(request.auth);
    await Promise.all([
      assertActive(recipientUid),
      consumeRateLimit(recipientUid, 'private_media_inbox_list'),
    ]);

    const grants = await db.collection('private_media_grants')
      .where('recipientUid', '==', recipientUid)
      .limit(250)
      .get();
    const mediaItems: FirebaseFirestore.DocumentData[] = [];
    for (const grant of grants.docs) {
      if (grant.get('active') !== true) continue;
      const ownerUid = String(grant.get('ownerUid') ?? '');
      const mediaId = String(grant.get('mediaId') ?? '');
      if (!ownerUid || !mediaId || !(await pairIsEligible(ownerUid, recipientUid))) continue;

      const media = await db.collection('private_media').doc(mediaId).get();
      if (!media.exists || media.get('ownerUid') !== ownerUid || media.get('status') !== 'active') continue;
      mediaItems.push({
        mediaId,
        ownerUid,
        ownerDisplayName: await displayName(ownerUid),
        grantedAtMs: millis(grant.get('createdAt')),
      });
    }
    return {media: mediaItems};
  },
);
