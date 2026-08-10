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
const terminalStatuses = new Set(['processed_pending_review', 'active', 'rejected', 'removed']);

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

async function consumeRateLimit(
  uid: string,
  action: string,
  max: number,
  windowMs: number,
): Promise<void> {
  const ref = db.collection('_rate_limits').doc(`${action}_${uid}`);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const start = Number(snap.get('windowStartMs') ?? 0);
    const count = Number(snap.get('count') ?? 0);
    if (!snap.exists || now - start >= windowMs) {
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
      throw new HttpsError('resource-exhausted', 'Too many profile-media requests. Try again later.');
    }
    tx.set(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
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

function requireProcessedPath(ownerUid: string, photoId: string, storagePath: string) {
  if (storagePath !== `users/${ownerUid}/profile/${photoId}.jpg`) {
    throw new HttpsError('failed-precondition', 'Invalid processed profile media path.');
  }
}

function requireOwnedProfileMediaPath(ownerUid: string, photoId: string, storagePath: string) {
  if (storagePath === `users/${ownerUid}/profile/${photoId}.jpg`) return;
  const quarantine = parseQuarantinePath(storagePath);
  if (quarantine?.uid === ownerUid && quarantine.photoId === photoId) return;
  throw new HttpsError('failed-precondition', 'Invalid profile media path.');
}

async function canViewOwnerProfile(requesterUid: string, ownerUid: string): Promise<boolean> {
  if (requesterUid === ownerUid) return true;
  await Promise.all([assertActive(requesterUid), assertActive(ownerUid)]);
  const pair = [requesterUid, ownerUid].sort().join('_');
  const [blockedAB, blockedBA, profile, match] = await Promise.all([
    db.collection('blocks').doc(`${requesterUid}_${ownerUid}`).get(),
    db.collection('blocks').doc(`${ownerUid}_${requesterUid}`).get(),
    db.collection('profiles').doc(ownerUid).get(),
    db.collection('matches').doc(pair).get(),
  ]);
  if (blockedAB.exists || blockedBA.exists || !profile.exists) return false;
  const visibility = String(profile.get('profileVisibility') ?? 'hidden');
  if (visibility === 'public') return true;
  return visibility === 'matches_only' && match.exists && match.get('active') === true;
}

export const beginProfilePhotoUpload = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const uid = requireUid(request.auth);
    await Promise.all([
      assertActive(uid),
      consumeRateLimit(uid, 'profile_photo_upload', 20, 24 * 60 * 60_000),
    ]);

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

    return {photoId, uploadUrl, expiresInSeconds: 600, requiredContentType: contentType};
  },
);

export const confirmProfilePhotoUpload = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const uid = requireUid(request.auth);
    await Promise.all([
      assertActive(uid),
      consumeRateLimit(uid, 'profile_photo_confirm', 60, 60 * 60_000),
    ]);

    const photoId = requirePhotoId(request.data?.photoId);
    const ref = db.collection('profile_media').doc(photoId);
    const photo = await ref.get();
    if (!photo.exists || photo.get('ownerUid') !== uid) {
      throw new HttpsError('not-found', 'Profile photo upload not found.');
    }

    const currentStatus = String(photo.get('status') ?? '');
    if (terminalStatuses.has(currentStatus) || currentStatus === 'pending_processing') {
      return {photoId, status: currentStatus};
    }
    if (currentStatus !== 'awaiting_upload') {
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
    if (!exists) {
      const refreshed = await ref.get();
      const refreshedStatus = String(refreshed.get('status') ?? '');
      if (terminalStatuses.has(refreshedStatus) || refreshedStatus === 'pending_processing') {
        return {photoId, status: refreshedStatus};
      }
      throw new HttpsError('failed-precondition', 'Uploaded file was not found.');
    }

    const [metadata] = await file.getMetadata();
    const size = Number(metadata.size ?? 0);
    const actualContentType = String(metadata.contentType ?? '').toLowerCase();
    if (size <= 0 || size > maxUploadBytes || actualContentType !== expectedContentType) {
      await file.delete({ignoreNotFound: true});
      await ref.set({status: 'rejected', rejectionReason: 'upload_validation', updatedAt: FieldValue.serverTimestamp()}, {merge: true});
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

    const currentStatus = String(photo.get('status') ?? '');
    if (terminalStatuses.has(currentStatus)) {
      await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
      return;
    }
    if (currentStatus !== 'awaiting_upload' && currentStatus !== 'pending_processing') {
      await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
      await ref.set({status: 'rejected', rejectionReason: 'invalid_processing_state', updatedAt: FieldValue.serverTimestamp()}, {merge: true});
      return;
    }

    const contentType = String(object.contentType ?? '').toLowerCase();
    const size = Number(object.size ?? 0);
    if (!allowedContentTypes.has(contentType) || size <= 0 || size > maxUploadBytes) {
      await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
      await ref.set({status: 'rejected', rejectionReason: 'storage_validation', updatedAt: FieldValue.serverTimestamp()}, {merge: true});
      return;
    }

    const expectedContentType = String(photo.get('contentType') ?? '').toLowerCase();
    if (contentType !== expectedContentType) {
      await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
      await ref.set({status: 'rejected', rejectionReason: 'content_type_mismatch', updatedAt: FieldValue.serverTimestamp()}, {merge: true});
      return;
    }

    const bucket = getStorage().bucket();
    const source = bucket.file(storagePath);
    try {
      await ref.set({
        status: 'pending_processing',
        uploadedAt: photo.get('uploadedAt') ?? FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        sizeBytes: size,
      }, {merge: true});

      const [input] = await source.download();
      const output = await sharp(input, {limitInputPixels: maxInputPixels})
        .rotate()
        .resize({width: 2048, height: 2048, fit: 'inside', withoutEnlargement: true})
        .jpeg({quality: 88, mozjpeg: true})
        .toBuffer();

      const destinationPath = `users/${uid}/profile/${photoId}.jpg`;
      await bucket.file(destinationPath).save(output, {
        resumable: false,
        contentType: 'image/jpeg',
        metadata: {
          cacheControl: 'private, max-age=300',
          metadata: {ownerUid: uid, photoId, processed: 'true'},
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
      await ref.set({status: 'rejected', rejectionReason: 'image_processing', updatedAt: FieldValue.serverTimestamp()}, {merge: true});
      const message = error instanceof Error ? error.message.slice(0, 300) : 'unknown';
      console.error('Profile photo processing failed', {photoId, message});
    }
  },
);

export const reviewProfilePhoto = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    const reviewerUid = requireUid(request.auth);
    await Promise.all([
      assertActive(reviewerUid),
      consumeRateLimit(reviewerUid, 'profile_photo_review', 120, 60 * 60_000),
    ]);
    if (request.auth?.token?.moderator !== true
        && request.auth?.token?.admin !== true
        && request.auth?.token?.superadmin !== true) {
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
    requireProcessedPath(ownerUid, photoId, storagePath);

    if (decision === 'reject') {
      await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
      await ref.set({
        status: 'rejected',
        rejectionReason: String(request.data?.reason ?? 'moderation').slice(0, 160),
        reviewedAt: FieldValue.serverTimestamp(),
        reviewedByUid: reviewerUid,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {photoId, status: 'rejected'};
    }

    await ref.set({
      status: 'active',
      reviewedAt: FieldValue.serverTimestamp(),
      reviewedByUid: reviewerUid,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {photoId, status: 'active'};
  },
);

export const getProfilePhotoAccess = onCall(
  {enforceAppCheck: true, maxInstances: 30},
  async (request) => {
    const requesterUid = requireUid(request.auth);
    await Promise.all([
      assertActive(requesterUid),
      consumeRateLimit(requesterUid, 'profile_photo_access', 120, 60_000),
    ]);
    const photoId = requirePhotoId(request.data?.photoId);
    const ref = db.collection('profile_media').doc(photoId);
    const photo = await ref.get();
    if (!photo.exists || photo.get('status') !== 'active') {
      throw new HttpsError('not-found', 'Profile photo is unavailable.');
    }
    const ownerUid = String(photo.get('ownerUid') ?? '');
    const storagePath = String(photo.get('storagePath') ?? '');
    requireProcessedPath(ownerUid, photoId, storagePath);
    if (!(await canViewOwnerProfile(requesterUid, ownerUid))) {
      throw new HttpsError('permission-denied', 'Profile photo is unavailable.');
    }

    const [url] = await getStorage().bucket().file(storagePath).getSignedUrl({
      action: 'read',
      expires: Date.now() + 2 * 60 * 1000,
    });
    return {url, expiresInSeconds: 120};
  },
);

export const deleteProfilePhoto = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const uid = requireUid(request.auth);
    await Promise.all([
      assertActive(uid),
      consumeRateLimit(uid, 'profile_photo_delete', 30, 60 * 60_000),
    ]);

    const photoId = requirePhotoId(request.data?.photoId);
    const ref = db.collection('profile_media').doc(photoId);
    const photo = await ref.get();
    if (!photo.exists || photo.get('ownerUid') !== uid) {
      throw new HttpsError('not-found', 'Profile photo not found.');
    }

    const storagePath = String(photo.get('storagePath') ?? '');
    requireOwnedProfileMediaPath(uid, photoId, storagePath);

    await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
    await ref.delete();
    return {deleted: true};
  },
);