import {randomUUID} from 'node:crypto';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {onObjectFinalized} from 'firebase-functions/v2/storage';
import sharp from 'sharp';
import {assertPrivateVaultEnabled, privateVaultServerEnabled} from './private_vault_gate';

const db = getFirestore();
const allowedContentTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);
const maxUploadBytes = 10 * 1024 * 1024;
const maxInputPixels = 40_000_000;
const terminalStatuses = new Set(['processed_pending_review', 'active', 'rejected', 'removed']);

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  assertPrivateVaultEnabled();
  return auth.uid;
}

function requireMediaId(raw: unknown): string {
  const value = String(raw ?? '').trim();
  if (!value || value.length > 80 || !/^[A-Za-z0-9-]+$/.test(value)) {
    throw new HttpsError('invalid-argument', 'Invalid mediaId.');
  }
  return value;
}

function requireContentType(raw: unknown): string {
  const value = String(raw ?? '').trim().toLowerCase();
  if (!allowedContentTypes.has(value)) {
    throw new HttpsError('invalid-argument', 'Unsupported image type.');
  }
  return value;
}

async function assertActive(uid: string): Promise<void> {
  const user = await db.collection('users').doc(uid).get();
  if (!user.exists || user.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Account is not active.');
  }
}

async function consumeRateLimit(uid: string, action: string, max: number, windowMs: number): Promise<void> {
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
      throw new HttpsError('resource-exhausted', 'Too many private-media uploads. Try again later.');
    }
    tx.set(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

function parseQuarantinePath(storagePath: string) {
  const match = /^private_media_quarantine\/([^/]+)\/([A-Za-z0-9-]+)\.(jpg|png|webp)$/.exec(storagePath);
  if (!match) return null;
  return {uid: match[1], mediaId: match[2]};
}

function requireProcessedPath(ownerUid: string, mediaId: string, storagePath: string): void {
  if (storagePath !== `private_media/${ownerUid}/${mediaId}.jpg`) {
    throw new HttpsError('failed-precondition', 'Invalid processed private-media path.');
  }
}

export const beginPrivateMediaUpload = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    const ownerUid = requireUid(request.auth);
    await assertActive(ownerUid);
    await consumeRateLimit(ownerUid, 'private_media_upload', 20, 24 * 60 * 60_000);

    if (request.data?.allSubjectsAdults !== true || request.data?.sharingRightsConfirmed !== true) {
      throw new HttpsError(
        'failed-precondition',
        'Confirm that all depicted people are adults and that you have permission to share this media.',
      );
    }

    const contentType = requireContentType(request.data?.contentType);
    const mediaId = randomUUID();
    const extension = contentType === 'image/jpeg' ? 'jpg' : contentType.split('/')[1];
    const quarantinePath = `private_media_quarantine/${ownerUid}/${mediaId}.${extension}`;
    const file = getStorage().bucket().file(quarantinePath);
    const expiresAt = Date.now() + 10 * 60 * 1000;

    const [uploadUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'write',
      expires: expiresAt,
      contentType,
    });

    await db.collection('private_media').doc(mediaId).set({
      mediaId,
      ownerUid,
      quarantinePath,
      contentType,
      status: 'awaiting_upload',
      adultSubjectsAttested: true,
      sharingRightsAttested: true,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      mediaId,
      uploadUrl,
      expiresInSeconds: 600,
      requiredContentType: contentType,
    };
  },
);

export const confirmPrivateMediaUpload = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    const ownerUid = requireUid(request.auth);
    await assertActive(ownerUid);
    const mediaId = requireMediaId(request.data?.mediaId);
    const ref = db.collection('private_media').doc(mediaId);
    const media = await ref.get();
    if (!media.exists || media.get('ownerUid') !== ownerUid) {
      throw new HttpsError('not-found', 'Private media upload not found.');
    }

    const currentStatus = String(media.get('status') ?? '');
    if (terminalStatuses.has(currentStatus) || currentStatus === 'pending_processing') {
      return {mediaId, status: currentStatus};
    }
    if (currentStatus !== 'awaiting_upload') {
      throw new HttpsError('failed-precondition', 'Upload is not awaiting confirmation.');
    }

    const quarantinePath = String(media.get('quarantinePath') ?? '');
    const parsed = parseQuarantinePath(quarantinePath);
    if (!parsed || parsed.uid !== ownerUid || parsed.mediaId !== mediaId) {
      throw new HttpsError('failed-precondition', 'Invalid private-media quarantine path.');
    }

    const file = getStorage().bucket().file(quarantinePath);
    const [exists] = await file.exists();
    if (!exists) {
      const refreshed = await ref.get();
      const refreshedStatus = String(refreshed.get('status') ?? '');
      if (terminalStatuses.has(refreshedStatus) || refreshedStatus === 'pending_processing') {
        return {mediaId, status: refreshedStatus};
      }
      throw new HttpsError('failed-precondition', 'Uploaded file was not found.');
    }

    const [metadata] = await file.getMetadata();
    const size = Number(metadata.size ?? 0);
    const actualContentType = String(metadata.contentType ?? '').toLowerCase();
    const expectedContentType = String(media.get('contentType') ?? '').toLowerCase();
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
      sizeBytes: size,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {mediaId, status: 'pending_processing'};
  },
);

export const processPrivateMedia = onObjectFinalized(
  {maxInstances: 5, memory: '1GiB'},
  async (event) => {
    const object = event.data;
    const storagePath = object.name ?? '';
    const parsed = parseQuarantinePath(storagePath);
    if (!parsed) return;

    const {uid: ownerUid, mediaId} = parsed;
    const source = getStorage().bucket().file(storagePath);

    // If the server kill switch is OFF, remove any quarantine object that may
    // have been uploaded using a previously-issued URL instead of processing it.
    if (!privateVaultServerEnabled) {
      await source.delete({ignoreNotFound: true});
      const disabledRef = db.collection('private_media').doc(mediaId);
      const disabledMedia = await disabledRef.get();
      if (disabledMedia.exists && disabledMedia.get('ownerUid') === ownerUid) {
        await disabledRef.set({
          status: 'rejected',
          rejectionReason: 'feature_disabled',
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      return;
    }

    const ref = db.collection('private_media').doc(mediaId);
    const media = await ref.get();
    if (!media.exists || media.get('ownerUid') !== ownerUid || media.get('quarantinePath') !== storagePath) {
      await source.delete({ignoreNotFound: true});
      return;
    }

    const currentStatus = String(media.get('status') ?? '');
    if (terminalStatuses.has(currentStatus)) {
      await source.delete({ignoreNotFound: true});
      return;
    }
    if (currentStatus !== 'awaiting_upload' && currentStatus !== 'pending_processing') {
      await source.delete({ignoreNotFound: true});
      await ref.set({
        status: 'rejected',
        rejectionReason: 'invalid_processing_state',
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return;
    }

    const contentType = String(object.contentType ?? '').toLowerCase();
    const size = Number(object.size ?? 0);
    const expectedContentType = String(media.get('contentType') ?? '').toLowerCase();
    if (!allowedContentTypes.has(contentType) || size <= 0 || size > maxUploadBytes || contentType !== expectedContentType) {
      await source.delete({ignoreNotFound: true});
      await ref.set({
        status: 'rejected',
        rejectionReason: 'storage_validation',
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return;
    }

    const bucket = getStorage().bucket();
    try {
      await ref.set({
        status: 'pending_processing',
        uploadedAt: media.get('uploadedAt') ?? FieldValue.serverTimestamp(),
        sizeBytes: size,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      const [input] = await source.download();
      const output = await sharp(input, {limitInputPixels: maxInputPixels})
        .rotate()
        .resize({width: 2048, height: 2048, fit: 'inside', withoutEnlargement: true})
        .jpeg({quality: 88, mozjpeg: true})
        .toBuffer();

      const destinationPath = `private_media/${ownerUid}/${mediaId}.jpg`;
      await bucket.file(destinationPath).save(output, {
        resumable: false,
        contentType: 'image/jpeg',
        metadata: {
          cacheControl: 'private, no-store, max-age=0',
          metadata: {
            ownerUid,
            mediaId,
            processed: 'true',
          },
        },
      });

      await ref.set({
        storagePath: destinationPath,
        contentType: 'image/jpeg',
        status: 'processed_pending_review',
        processedAt: FieldValue.serverTimestamp(),
        processedSizeBytes: output.length,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await source.delete({ignoreNotFound: true});
    } catch (error) {
      await source.delete({ignoreNotFound: true});
      await ref.set({
        status: 'rejected',
        rejectionReason: 'image_processing',
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      console.error('Private media processing failed', {ownerUid, mediaId, error});
    }
  },
);

export const reviewPrivateMedia = onCall(
  {enforceAppCheck: true, maxInstances: 5},
  async (request) => {
    requireUid(request.auth);
    if (request.auth?.token?.moderator !== true && request.auth?.token?.admin !== true) {
      throw new HttpsError('permission-denied', 'Moderator access required.');
    }

    const mediaId = requireMediaId(request.data?.mediaId);
    const decision = String(request.data?.decision ?? '').trim();
    if (decision !== 'approve' && decision !== 'reject') {
      throw new HttpsError('invalid-argument', 'Decision must be approve or reject.');
    }

    const ref = db.collection('private_media').doc(mediaId);
    const media = await ref.get();
    if (!media.exists || media.get('status') !== 'processed_pending_review') {
      throw new HttpsError('failed-precondition', 'Private media is not awaiting review.');
    }

    const ownerUid = String(media.get('ownerUid') ?? '');
    const storagePath = String(media.get('storagePath') ?? '');
    requireProcessedPath(ownerUid, mediaId, storagePath);

    if (decision === 'reject') {
      await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
      await ref.set({
        status: 'rejected',
        rejectionReason: String(request.data?.reason ?? 'moderation').slice(0, 160),
        reviewedAt: FieldValue.serverTimestamp(),
        reviewedByUid: request.auth!.uid,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {mediaId, status: 'rejected'};
    }

    await ref.set({
      status: 'active',
      reviewedAt: FieldValue.serverTimestamp(),
      reviewedByUid: request.auth!.uid,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {mediaId, status: 'active'};
  },
);

export const listMyPrivateMedia = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    const ownerUid = requireUid(request.auth);
    await assertActive(ownerUid);
    const snap = await db.collection('private_media')
      .where('ownerUid', '==', ownerUid)
      .limit(100)
      .get();

    return {
      media: snap.docs.map((doc) => ({
        mediaId: doc.id,
        status: String(doc.get('status') ?? 'unknown'),
        contentType: String(doc.get('contentType') ?? ''),
        createdAtMs: doc.get('createdAt')?.toMillis?.() ?? null,
        processedAtMs: doc.get('processedAt')?.toMillis?.() ?? null,
        reviewedAtMs: doc.get('reviewedAt')?.toMillis?.() ?? null,
      })),
    };
  },
);
