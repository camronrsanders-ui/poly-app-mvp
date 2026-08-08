import {randomUUID} from 'node:crypto';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

const db = getFirestore();
const allowedContentTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

async function assertActive(uid: string) {
  const user = await db.collection('users').doc(uid).get();
  if (!user.exists || user.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Account is not active.');
  }
}

function requireContentType(raw: unknown): string {
  const value = String(raw ?? '').trim().toLowerCase();
  if (!allowedContentTypes.has(value)) {
    throw new HttpsError('invalid-argument', 'Unsupported image type.');
  }
  return value;
}

function requirePhotoId(raw: unknown): string {
  const value = String(raw ?? '').trim();
  if (!value || value.length > 80 || !/^[A-Za-z0-9-]+$/.test(value)) {
    throw new HttpsError('invalid-argument', 'Invalid photoId.');
  }
  return value;
}

export const beginProfilePhotoUpload = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const uid = requireUid(request.auth);
    await assertActive(uid);

    const contentType = requireContentType(request.data?.contentType);
    const photoId = randomUUID();
    const extension = contentType === 'image/jpeg' ? 'jpg' : contentType.split('/')[1];
    const storagePath = `users/${uid}/profile_quarantine/${photoId}.${extension}`;
    const file = getStorage().bucket().file(storagePath);
    const expiresAt = Date.now() + 10 * 60 * 1000;

    const [uploadUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'write',
      expires: expiresAt,
      contentType,
    });

    await db.collection('profile_media').doc(photoId).set({
      photoId,
      ownerUid: uid,
      storagePath,
      contentType,
      status: 'awaiting_upload',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      photoId,
      uploadUrl,
      expiresInSeconds: 600,
      requiredContentType: contentType,
    };
  },
);

export const confirmProfilePhotoUpload = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const uid = requireUid(request.auth);
    await assertActive(uid);

    const photoId = requirePhotoId(request.data?.photoId);
    const ref = db.collection('profile_media').doc(photoId);
    const photo = await ref.get();
    if (!photo.exists || photo.get('ownerUid') !== uid) {
      throw new HttpsError('not-found', 'Profile photo upload not found.');
    }
    if (photo.get('status') !== 'awaiting_upload') {
      throw new HttpsError('failed-precondition', 'Upload is not awaiting confirmation.');
    }

    const storagePath = String(photo.get('storagePath') ?? '');
    const expectedContentType = String(photo.get('contentType') ?? '');
    const file = getStorage().bucket().file(storagePath);
    const [exists] = await file.exists();
    if (!exists) throw new HttpsError('failed-precondition', 'Uploaded file was not found.');

    const [metadata] = await file.getMetadata();
    const size = Number(metadata.size ?? 0);
    const actualContentType = String(metadata.contentType ?? '').toLowerCase();
    if (size <= 0 || size > 10 * 1024 * 1024 || actualContentType !== expectedContentType) {
      await file.delete({ignoreNotFound: true});
      await ref.set({
        status: 'rejected',
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      throw new HttpsError('invalid-argument', 'Uploaded image failed validation.');
    }

    await ref.set({
      status: 'pending_processing',
      uploadedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      sizeBytes: size,
    }, {merge: true});

    return {photoId, status: 'pending_processing'};
  },
);

export const deleteProfilePhoto = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const uid = requireUid(request.auth);
    await assertActive(uid);

    const photoId = requirePhotoId(request.data?.photoId);
    const ref = db.collection('profile_media').doc(photoId);
    const photo = await ref.get();
    if (!photo.exists || photo.get('ownerUid') !== uid) {
      throw new HttpsError('not-found', 'Profile photo not found.');
    }

    const storagePath = String(photo.get('storagePath') ?? '');
    const expectedPrefix = `users/${uid}/`;
    if (!storagePath.startsWith(expectedPrefix)) {
      throw new HttpsError('failed-precondition', 'Invalid profile media path.');
    }

    await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
    await ref.delete();

    return {deleted: true};
  },
);
