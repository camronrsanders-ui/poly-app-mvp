import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {assertPrivateVaultEnabled} from './private_vault_gate';

const db = getFirestore();

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

async function assertActive(uid: string): Promise<void> {
  const user = await db.collection('users').doc(uid).get();
  if (!user.exists || user.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Account is not active.');
  }
}

async function consumeRateLimit(uid: string): Promise<void> {
  const action = 'private_media_request_cancel';
  const ref = db.collection('_rate_limits').doc(`${action}_${uid}`);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const start = Number(snap.get('windowStartMs') ?? 0);
    const count = Number(snap.get('count') ?? 0);
    if (!snap.exists || now - start >= 60 * 60_000) {
      tx.set(ref, {
        uid,
        action,
        windowStartMs: now,
        count: 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }
    if (count >= 30) {
      throw new HttpsError('resource-exhausted', 'Too many requests. Try again later.');
    }
    tx.set(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

export const cancelPrivateMediaRequest = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    const requesterUid = requireUid(request.auth);
    const requestId = requireId(request.data?.requestId, 'requestId');
    await Promise.all([assertActive(requesterUid), consumeRateLimit(requesterUid)]);

    const requestRef = db.collection('private_media_requests').doc(requestId);
    const requestSnap = await requestRef.get();
    if (!requestSnap.exists || requestSnap.get('requesterUid') !== requesterUid) {
      throw new HttpsError('not-found', 'Private-media request not found.');
    }

    const ownerUid = String(requestSnap.get('recipientUid') ?? '');
    if (!ownerUid) throw new HttpsError('failed-precondition', 'Invalid private-media request state.');

    // Query the exact owner/recipient pair before revoking. The old recipient-only
    // capped query could miss this owner's grants after enough unrelated history
    // accumulated, causing withdrawn consent to be incomplete.
    const grants = await db.collection('private_media_grants')
      .where('ownerUid', '==', ownerUid)
      .where('recipientUid', '==', requesterUid)
      .where('active', '==', true)
      .get();

    const writer = db.bulkWriter();
    for (const grant of grants.docs) {
      writer.set(grant.ref, {
        active: false,
        revokedAt: FieldValue.serverTimestamp(),
        revokedReason: 'recipient_cancelled_request',
      }, {merge: true});
    }
    await writer.close();

    // Mark the request cancelled only after every currently-active grant for
    // the pair has been revoked. A failure leaves the accepted request intact,
    // making retry semantics explicit instead of reporting false completion.
    await requestRef.set({
      status: 'cancelled',
      cancelledAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    return {cancelled: true, revokedGrantCount: grants.size};
  },
);
