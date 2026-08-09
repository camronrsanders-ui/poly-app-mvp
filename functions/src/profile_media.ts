import {randomUUID} from 'node:crypto';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {onObjectFinalized} from 'firebase-functions/v2/storage';
import sharp from 'sharp';

const db = getFirestore();
const allowedContentTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);
const quarantinePrefix = 'profile_quarantine';
const maxUploadBytes = 10 * 1024 * 1024;
const maxInputPixels = 40_000_000;

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

function parseQuarantinePath(storagePath: string) {
  const match = /^users\/([^/]+)\/profile_quarantine\/([A-Za-z0-9-]+)\.(jpg|png|webp)$/.exec(storagePath);
  if (!match) return null;
  return {uid: match[1], photoId: match[2]};
}

export const beginProfilePhotoUpload = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const uid = requireUid(request.auth);
    await assertActive(uid);

    const contentType = requireContentType(request.data?.contentType);
    const photoId = randomUUID();
    const extension = contentType === 'image/jpeg' ? 'jpg' : contentType.split('/')[1];
    const storagePath = `users/${uid}/${quarantinePrefix}/${photoId}.${extension}`;
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
    const parsed = parseQuarantinePath(storagePath);
    if (!parsed || parsed.uid !== uid || parsed.photoId !== photoId) {
      throw new HttpsError('failed-precondition', 'Invalid profile media path.');
    }

    const file = getStorage().bucket().file(storagePath);
    const [exists] = await file.exists();
    if (!exists) throw new HttpsError('failed-precondition', 'Uploaded file was not found.');

    const [metadata] = await file.getMetadata();
    const size = Number(metadata.size ?? 0);
    const actualContentType = String(metadata.contentType ?? '').toLowerCase();
    if (size <= 0 || size > maxUploadBytes || actualContentType !== expectedContentType) {
      await file.delete({ignoreNotFound: true});
      await ref.set({
        status: 'rejected',
        rejectionReason: 'upload_validation',
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

export const processProfilePhoto = onObjectFinalized(
  {maxInstances: 10, memory: '1GiB'},
  async (event) => {
    const object = event.data;
    const storagePath = object.name ?? '';
    const parsed = parseQuarantinePath(storagePath);
    if (!parsed) return;

    const {uid, photoId} = parsed;
    const ref = db.collection('profile_media').doc(photoId);
    const photo = await ref.get();
    if (!photo.exists || photo.get('ownerUid') !== uid || photo.get('storagePath') !== storagePath) {
      await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
      return;
    }

    const contentType = String(object.contentType ?? '').toLowerCase();
    const size = Number(object.size ?? 0);
    if (!allowedContentTypes.has(contentType) || size <= 0 || size > maxUploadBytes) {
      await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
      await ref.set({
        status: 'rejected',
        rejectionReason: 'storage_validation',
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return;
    }

    const bucket = getStorage().bucket();
    const source = bucket.file(storagePath);
    try {
      const [input] = await source.download();
      const output = await sharp(input, {limitInputPixels: maxInputPixels})
        .rotate()
        .resize({width: 2048, height: 2048, fit: 'inside', withoutEnlargement: true})
        .jpeg({quality: 88, mozjpeg: true})
        .toBuffer();

      const destinationPath = `users/${uid}/profile/${photoId}.jpg`;
      const destination = bucket.file(destinationPath);
      await destination.save(output, {
        resumable: false,
        contentType: 'image/jpeg',
        metadata: {
          cacheControl: 'private, max-age=300',
          metadata: {
            ownerUid: uid,
            photoId,
            processed: 'true',
          },
        },
      });

      await ref.set({
        storagePath: destinationPath,
        contentType: 'image/jpeg',
        status: 'processed_pending_review',
        processedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        processedSizeBytes: output.length,
      }, {merge: true});
      await source.delete({ignoreNotFound: true});
    } catch (error) {
      await source.delete({ignoreNotFound: true});
      await ref.set({
        status: 'rejected',
        rejectionReason: 'image_processing',
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      console.error('Profile photo processing failed', {uid, photoId, error});
    }
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
    if (!storagePath.startsWith(expectedPrefix) || storagePath.includes('..')) {
      throw new HttpsError('failed-precondition', 'Invalid profile media path.');
    }

    await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
    await ref.delete();

    return {deleted: true};
  },
);
