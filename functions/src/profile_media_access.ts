import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

const db = getFirestore();

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

function requirePhotoId(raw: unknown): string {
  const value = String(raw ?? '').trim();
  if (!value || value.length > 80 || !/^[A-Za-z0-9-]+$/.test(value)) {
    throw new HttpsError('invalid-argument', 'Invalid photoId.');
  }
  return value;
}

async function assertActive(uid: string): Promise<void> {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists || snap.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Account is not active.');
  }
}

async function isBlocked(a: string, b: string): Promise<boolean> {
  const [ab, ba] = await Promise.all([
    db.collection('blocks').doc(`${a}_${b}`).get(),
    db.collection('blocks').doc(`${b}_${a}`).get(),
  ]);
  return ab.exists || ba.exists;
}

async function hasActiveMatch(a: string, b: string): Promise<boolean> {
  const match = await db.collection('matches').doc([a, b].sort().join('_')).get();
  return match.exists && match.get('active') === true;
}

function assertProcessedOwnerPath(ownerUid: string, photoId: string, storagePath: string): void {
  const expected = `users/${ownerUid}/profile/${photoId}.jpg`;
  if (storagePath !== expected) {
    throw new HttpsError('failed-precondition', 'Invalid processed profile-media path.');
  }
}

export const reviewProfilePhoto = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    requireUid(request.auth);
    const claims = request.auth?.token ?? {};
    if (claims.admin !== true && claims.moderator !== true) {
      throw new HttpsError('permission-denied', 'Moderator access required.');
    }

    const photoId = requirePhotoId(request.data?.photoId);
    const decision = String(request.data?.decision ?? '').trim();
    if (decision !== 'approve' && decision !== 'reject') {
      throw new HttpsError('invalid-argument', 'Decision must be approve or reject.');
    }

    const ref = db.collection('profile_media').doc(photoId);
    const photo = await ref.get();
    if (!photo.exists || photo.get('status') !== 'processed_pending_review') {
      throw new HttpsError('failed-precondition', 'Photo is not awaiting review.');
    }

    const ownerUid = String(photo.get('ownerUid') ?? '');
    const storagePath = String(photo.get('storagePath') ?? '');
    if (!ownerUid || !storagePath) {
      throw new HttpsError('failed-precondition', 'Profile photo metadata is incomplete.');
    }
    assertProcessedOwnerPath(ownerUid, photoId, storagePath);

    if (decision === 'reject') {
      await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
      await ref.set({
        status: 'rejected',
        rejectionReason: 'moderation',
        reviewedAt: FieldValue.serverTimestamp(),
        reviewedByUid: request.auth!.uid,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {photoId, status: 'rejected'};
    }

    await ref.set({
      status: 'active',
      reviewedAt: FieldValue.serverTimestamp(),
      reviewedByUid: request.auth!.uid,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {photoId, status: 'active'};
  },
);

export const getProfilePhotoAccess = onCall(
  {enforceAppCheck: true, maxInstances: 30},
  async (request) => {
    const viewerUid = requireUid(request.auth);
    const photoId = requirePhotoId(request.data?.photoId);
    await assertActive(viewerUid);

    const media = await db.collection('profile_media').doc(photoId).get();
    if (!media.exists || media.get('status') !== 'active') {
      throw new HttpsError('not-found', 'Profile photo is unavailable.');
    }

    const ownerUid = String(media.get('ownerUid') ?? '');
    const storagePath = String(media.get('storagePath') ?? '');
    if (!ownerUid || !storagePath) {
      throw new HttpsError('failed-precondition', 'Profile photo metadata is incomplete.');
    }
    assertProcessedOwnerPath(ownerUid, photoId, storagePath);
    await assertActive(ownerUid);

    if (viewerUid !== ownerUid) {
      if (await isBlocked(viewerUid, ownerUid)) {
        throw new HttpsError('permission-denied', 'Profile photo is unavailable.');
      }

      const profile = await db.collection('profiles').doc(ownerUid).get();
      if (!profile.exists) throw new HttpsError('not-found', 'Profile is unavailable.');
      const visibility = String(profile.get('profileVisibility') ?? 'hidden');
      if (visibility === 'hidden') {
        throw new HttpsError('permission-denied', 'Profile photo is unavailable.');
      }
      if (visibility === 'matches_only' && !(await hasActiveMatch(viewerUid, ownerUid))) {
        throw new HttpsError('permission-denied', 'Profile photo is unavailable.');
      }
      if (visibility !== 'public' && visibility !== 'matches_only') {
        throw new HttpsError('permission-denied', 'Profile photo is unavailable.');
      }
    }

    const [url] = await getStorage().bucket().file(storagePath).getSignedUrl({
      action: 'read',
      expires: Date.now() + 2 * 60 * 1000,
    });
    return {url, expiresInSeconds: 120};
  },
);
