import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {assertPrivateVaultEnabled} from './private_vault_gate';

const db = getFirestore();
const privateMediaReportReasons = new Set([
  'nonconsensual_content',
  'harassment',
  'misrepresentation',
  'illegal_content',
  'other',
]);

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  assertPrivateVaultEnabled();
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

async function assertAcceptedShareRequest(ownerUid: string, recipientUid: string) {
  // The viewer requests access from the owner. The owner may share only after
  // that viewer has explicitly asked and the owner accepted the request.
  const requestId = `${recipientUid}_${ownerUid}`;
  const request = await db.collection('private_media_requests').doc(requestId).get();
  if (!request.exists
      || request.get('requesterUid') !== recipientUid
      || request.get('recipientUid') !== ownerUid
      || request.get('status') !== 'accepted') {
    throw new HttpsError(
      'failed-precondition',
      'An accepted private-media request is required before sharing.',
    );
  }
  return request.ref;
}

function requireOwnerStoragePath(ownerUid: string, storagePath: string) {
  const prefix = `private_media/${ownerUid}/`;
  if (!storagePath.startsWith(prefix) || storagePath.includes('..')) {
    throw new HttpsError('failed-precondition', 'Invalid private media storage path.');
  }
}

function requestPreferenceId(recipientUid: string, requesterUid: string) {
  return `${recipientUid}_${requesterUid}`;
}

export const requestPrivateMedia = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const requesterUid = requireUid(request.auth);
    const recipientUid = requireId(request.data?.recipientUid, 'recipientUid');
    await Promise.all([
      assertEligiblePair(requesterUid, recipientUid),
      consumeRateLimit(requesterUid, 'private_media_request', 8, 24 * 60 * 60_000),
    ]);

    const preference = await db.collection('private_media_request_preferences')
      .doc(requestPreferenceId(recipientUid, requesterUid))
      .get();
    if (preference.exists && preference.get('doNotAskAgain') === true) {
      throw new HttpsError('permission-denied', 'This person is not accepting private-media requests from you.');
    }

    const requestId = `${requesterUid}_${recipientUid}`;
    const ref = db.collection('private_media_requests').doc(requestId);
    const existing = await ref.get();
    if (existing.exists && existing.get('status') === 'pending') {
      throw new HttpsError('already-exists', 'A private-media request is already pending.');
    }

    await ref.set({
      requestId,
      requesterUid,
      recipientUid,
      status: 'pending',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {requestId, status: 'pending'};
  },
);

export const respondToPrivateMediaRequest = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const recipientUid = requireUid(request.auth);
    const requestId = requireId(request.data?.requestId, 'requestId');
    const decision = String(request.data?.decision ?? '').trim();
    const doNotAskAgain = request.data?.doNotAskAgain === true;
    if (!['accepted', 'declined'].includes(decision)) {
      throw new HttpsError('invalid-argument', 'Invalid request decision.');
    }
    await Promise.all([
      assertActive(recipientUid),
      consumeRateLimit(recipientUid, 'private_media_request_response', 30, 60 * 60_000),
    ]);

    const ref = db.collection('private_media_requests').doc(requestId);
    const snap = await ref.get();
    if (!snap.exists || snap.get('recipientUid') !== recipientUid) {
      throw new HttpsError('not-found', 'Private-media request not found.');
    }
    if (snap.get('status') !== 'pending') {
      throw new HttpsError('failed-precondition', 'This request is no longer pending.');
    }

    const requesterUid = String(snap.get('requesterUid') ?? '');
    if (!requesterUid) throw new HttpsError('failed-precondition', 'Invalid request state.');
    await assertEligiblePair(requesterUid, recipientUid);

    // Apply the response and optional do-not-ask preference atomically so the
    // user never sees a successful response while their privacy preference was
    // silently lost to a second write failure.
    const batch = db.batch();
    batch.set(ref, {
      status: decision,
      respondedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    if (doNotAskAgain) {
      batch.set(
        db.collection('private_media_request_preferences')
          .doc(requestPreferenceId(recipientUid, requesterUid)),
        {
          recipientUid,
          requesterUid,
          doNotAskAgain: true,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }
    await batch.commit();

    // Accepting a request only grants permission to offer/share media later.
    // It never automatically grants access to any existing or future media.
    return {status: decision, doNotAskAgain};
  },
);

export const clearPrivateMediaRequestPreference = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    const recipientUid = requireUid(request.auth);
    const requesterUid = requireId(request.data?.requesterUid, 'requesterUid');
    await Promise.all([
      assertActive(recipientUid),
      consumeRateLimit(recipientUid, 'private_media_preference_clear', 30, 60 * 60_000),
    ]);
    await db.collection('private_media_request_preferences')
      .doc(requestPreferenceId(recipientUid, requesterUid))
      .delete();
    return {cleared: true};
  },
);

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
    const acceptedRequestRef = await assertAcceptedShareRequest(ownerUid, recipientUid);

    const mediaRef = db.collection('private_media').doc(mediaId);
    const media = await mediaRef.get();
    if (!media.exists || media.get('ownerUid') !== ownerUid || media.get('status') !== 'active') {
      throw new HttpsError('not-found', 'Private media is unavailable.');
    }

    const storagePath = String(media.get('storagePath') ?? '');
    requireOwnerStoragePath(ownerUid, storagePath);

    const grantId = `${mediaId}_${recipientUid}`;
    await Promise.all([
      db.collection('private_media_grants').doc(grantId).set({
        mediaId,
        ownerUid,
        recipientUid,
        active: true,
        createdAt: FieldValue.serverTimestamp(),
        revokedAt: null,
        revokedReason: null,
      }, {merge: true}),
      acceptedRequestRef.set({
        lastSharedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true}),
    ]);

    return {grantId};
  },
);

export const revokePrivateMedia = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const ownerUid = requireUid(request.auth);
    const mediaId = requireId(request.data?.mediaId, 'mediaId');
    const recipientUid = requireId(request.data?.recipientUid, 'recipientUid');
    await Promise.all([
      assertActive(ownerUid),
      consumeRateLimit(ownerUid, 'private_media_revoke', 120, 60 * 60_000),
    ]);

    const grantRef = db.collection('private_media_grants').doc(`${mediaId}_${recipientUid}`);
    const grant = await grantRef.get();
    if (!grant.exists || grant.get('ownerUid') !== ownerUid || grant.get('recipientUid') !== recipientUid) {
      throw new HttpsError('not-found', 'Private media grant not found.');
    }

    await grantRef.set({
      active: false,
      revokedAt: FieldValue.serverTimestamp(),
      revokedReason: 'owner_revoked',
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

export const reportPrivateMedia = onCall(
  {enforceAppCheck: true, maxInstances: 15},
  async (request) => {
    const reporterUid = requireUid(request.auth);
    const mediaId = requireId(request.data?.mediaId, 'mediaId');
    const reason = String(request.data?.reason ?? '').trim();
    const details = String(request.data?.details ?? '').trim();
    if (!privateMediaReportReasons.has(reason)) {
      throw new HttpsError('invalid-argument', 'Invalid private-media report reason.');
    }
    if (details.length > 2000) {
      throw new HttpsError('invalid-argument', 'Report details are too long.');
    }
    await Promise.all([
      assertActive(reporterUid),
      consumeRateLimit(reporterUid, 'private_media_report', 8, 24 * 60 * 60_000),
    ]);

    const media = await db.collection('private_media').doc(mediaId).get();
    if (!media.exists) throw new HttpsError('not-found', 'Private media not found.');
    const ownerUid = String(media.get('ownerUid') ?? '');
    if (!ownerUid || ownerUid === reporterUid) {
      throw new HttpsError('invalid-argument', 'Invalid private-media report target.');
    }

    // Reporting remains available after a grant is revoked so a recipient can
    // report media they previously received without needing current access.
    const grant = await db.collection('private_media_grants')
      .doc(`${mediaId}_${reporterUid}`)
      .get();
    if (!grant.exists || grant.get('recipientUid') !== reporterUid || grant.get('ownerUid') !== ownerUid) {
      throw new HttpsError('permission-denied', 'You cannot report this private-media item.');
    }

    const reportRef = db.collection('reports').doc();
    await reportRef.set({
      reportId: reportRef.id,
      reporterUid,
      reportedUid: ownerUid,
      subjectType: 'private_media',
      subjectId: mediaId,
      reason,
      details,
      status: 'open',
      createdAt: FieldValue.serverTimestamp(),
    });

    await db.collection('private_media').doc(mediaId).set({
      reportedAt: FieldValue.serverTimestamp(),
      hasOpenReport: true,
    }, {merge: true});

    return {submitted: true, reportId: reportRef.id};
  },
);