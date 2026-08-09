import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

const db = getFirestore();

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

function requireId(raw: unknown, label: string): string {
  const value = String(raw ?? '').trim();
  if (!value || value.length > 160 || !/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new HttpsError('invalid-argument', `Invalid ${label}.`);
  }
  return value;
}

function pairId(a: string, b: string): string {
  return [a, b].sort().join('_');
}

async function assertActive(uid: string) {
  const user = await db.collection('users').doc(uid).get();
  if (!user.exists || user.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Account is not active.');
  }
}

async function consumeRateLimit(uid: string, action: string, max: number, windowMs: number) {
  const ref = db.collection('_rate_limits').doc(`${action}_${uid}`);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const start = Number(snap.get('windowStartMs') ?? 0);
    const count = Number(snap.get('count') ?? 0);
    if (!snap.exists || now - start >= windowMs) {
      tx.set(ref, {uid, action, windowStartMs: now, count: 1, updatedAt: FieldValue.serverTimestamp()});
      return;
    }
    if (count >= max) {
      throw new HttpsError('resource-exhausted', 'Too many private-media requests. Try again later.');
    }
    tx.set(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

async function assertEligiblePair(ownerUid: string, recipientUid: string) {
  if (ownerUid === recipientUid) {
    throw new HttpsError('invalid-argument', 'You cannot share private media with yourself.');
  }
  await Promise.all([assertActive(ownerUid), assertActive(recipientUid)]);

  const [ab, ba, match] = await Promise.all([
    db.collection('blocks').doc(`${ownerUid}_${recipientUid}`).get(),
    db.collection('blocks').doc(`${recipientUid}_${ownerUid}`).get(),
    db.collection('matches').doc(pairId(ownerUid, recipientUid)).get(),
  ]);

  if (ab.exists || ba.exists) {
    throw new HttpsError('permission-denied', 'Private sharing is unavailable.');
  }
  if (!match.exists || match.get('active') !== true) {
    throw new HttpsError('failed-precondition', 'An active match is required.');
  }
}

function requireOwnerStoragePath(ownerUid: string, storagePath: string) {
  const prefix = `private_media/${ownerUid}/`;
  if (!storagePath.startsWith(prefix) || storagePath.includes('..')) {
    throw new HttpsError('failed-precondition', 'Invalid private media storage path.');
  }
}

export const grantPrivateMedia = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const ownerUid = requireUid(request.auth);
    const mediaId = requireId(request.data?.mediaId, 'mediaId');
    const recipientUid = requireId(request.data?.recipientUid, 'recipientUid');

    await Promise.all([
      assertEligiblePair(ownerUid, recipientUid),
      consumeRateLimit(ownerUid, 'private_media_grant', 60, 60 * 60_000),
    ]);

    const mediaRef = db.collection('private_media').doc(mediaId);
    const media = await mediaRef.get();
    if (!media.exists || media.get('ownerUid') !== ownerUid || media.get('status') !== 'active') {
      throw new HttpsError('not-found', 'Private media is unavailable.');
    }

    const storagePath = String(media.get('storagePath') ?? '');
    requireOwnerStoragePath(ownerUid, storagePath);

    const grantId = `${mediaId}_${recipientUid}`;
    await db.collection('private_media_grants').doc(grantId).set({
      mediaId,
      ownerUid,
      recipientUid,
      active: true,
      createdAt: FieldValue.serverTimestamp(),
      revokedAt: null,
    }, {merge: true});

    return {grantId};
  },
);

export const revokePrivateMedia = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const ownerUid = requireUid(request.auth);
    const mediaId = requireId(request.data?.mediaId, 'mediaId');
    const recipientUid = requireId(request.data?.recipientUid, 'recipientUid');
    await consumeRateLimit(ownerUid, 'private_media_revoke', 120, 60 * 60_000);

    const grantRef = db.collection('private_media_grants').doc(`${mediaId}_${recipientUid}`);
    const grant = await grantRef.get();
    if (!grant.exists || grant.get('ownerUid') !== ownerUid) {
      throw new HttpsError('not-found', 'Private media grant not found.');
    }

    await grantRef.set({
      active: false,
      revokedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    return {revoked: true};
  },
);

export const getPrivateMediaAccess = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const recipientUid = requireUid(request.auth);
    const mediaId = requireId(request.data?.mediaId, 'mediaId');
    await consumeRateLimit(recipientUid, 'private_media_access', 90, 60 * 60_000);

    const mediaRef = db.collection('private_media').doc(mediaId);
    const media = await mediaRef.get();
    if (!media.exists || media.get('status') !== 'active') {
      throw new HttpsError('not-found', 'Private media is unavailable.');
    }

    const ownerUid = String(media.get('ownerUid') ?? '');
    const storagePath = String(media.get('storagePath') ?? '');
    if (!ownerUid || !storagePath) {
      throw new HttpsError('failed-precondition', 'Private media is not ready.');
    }
    requireOwnerStoragePath(ownerUid, storagePath);

    await assertEligiblePair(ownerUid, recipientUid);

    const grant = await db.collection('private_media_grants')
      .doc(`${mediaId}_${recipientUid}`)
      .get();
    if (!grant.exists || grant.get('active') !== true || grant.get('ownerUid') !== ownerUid) {
      throw new HttpsError('permission-denied', 'No active private media grant.');
    }

    const [signedUrl] = await getStorage().bucket().file(storagePath).getSignedUrl({
      action: 'read',
      expires: Date.now() + 2 * 60 * 1000,
    });

    return {url: signedUrl, expiresInSeconds: 120};
  },
);
