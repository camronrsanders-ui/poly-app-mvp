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

async function consumeRateLimit(uid: string): Promise<void> {
  const action = 'profile_photo_list';
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
    if (count >= 60) {
      throw new HttpsError('resource-exhausted', 'Too many profile-photo requests. Try again later.');
    }
    tx.set(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

function timestampMillis(value: unknown): number | null {
  const candidate = value as {toMillis?: () => number} | null | undefined;
  return candidate?.toMillis?.() ?? null;
}

export const listMyProfilePhotos = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const uid = requireUid(request.auth);
    await Promise.all([assertActive(uid), consumeRateLimit(uid)]);

    const snapshot = await db.collection('profile_media')
      .where('ownerUid', '==', uid)
      .limit(20)
      .get();

    const photos = snapshot.docs.map((doc) => ({
      photoId: doc.id,
      status: String(doc.get('status') ?? 'unknown'),
      contentType: String(doc.get('contentType') ?? ''),
      createdAtMs: timestampMillis(doc.get('createdAt')),
      processedAtMs: timestampMillis(doc.get('processedAt')),
      reviewedAtMs: timestampMillis(doc.get('reviewedAt')),
    }));

    photos.sort((a, b) => (b.createdAtMs ?? 0) - (a.createdAtMs ?? 0));
    return {photos};
  },
);
