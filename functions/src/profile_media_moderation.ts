import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

const db = getFirestore();

function requireModerator(auth: {uid: string; token?: Record<string, unknown>} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  if (auth.token?.moderator !== true && auth.token?.admin !== true && auth.token?.superadmin !== true) {
    throw new HttpsError('permission-denied', 'Moderator access required.');
  }
  return auth.uid;
}

async function assertActive(uid: string): Promise<void> {
  const user = await db.collection('users').doc(uid).get();
  if (!user.exists || user.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Moderator account is not active.');
  }
}

async function consumeRateLimit(uid: string, max: number, windowMs: number): Promise<void> {
  const action = 'profile_photo_moderation_list';
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
      throw new HttpsError('resource-exhausted', 'Too many moderation requests. Try again later.');
    }
    tx.set(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

function timestampMillis(value: unknown): number | null {
  const candidate = value as {toMillis?: () => number} | null | undefined;
  return candidate?.toMillis?.() ?? null;
}

function requireProcessedPath(ownerUid: string, photoId: string, storagePath: string): boolean {
  return storagePath === `users/${ownerUid}/profile/${photoId}.jpg`;
}

export const listProfilePhotosForReview = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    const moderatorUid = requireModerator(request.auth);
    await Promise.all([
      assertActive(moderatorUid),
      consumeRateLimit(moderatorUid, 120, 60_000),
    ]);

    const requestedLimit = Number(request.data?.limit ?? 30);
    const limit = Number.isFinite(requestedLimit)
      ? Math.min(Math.max(Math.trunc(requestedLimit), 1), 50)
      : 30;

    const snapshot = await db.collection('profile_media')
      .where('status', '==', 'processed_pending_review')
      .limit(limit)
      .get();
    if (snapshot.empty) return {photos: []};

    const valid = snapshot.docs
      .map((doc) => {
        const ownerUid = String(doc.get('ownerUid') ?? '');
        const storagePath = String(doc.get('storagePath') ?? '');
        if (!ownerUid || !requireProcessedPath(ownerUid, doc.id, storagePath)) return null;
        return {doc, ownerUid, storagePath};
      })
      .filter((item): item is NonNullable<typeof item> => item !== null);
    if (valid.length === 0) return {photos: []};

    const profileRefs = valid.map(({ownerUid}) => db.collection('profiles').doc(ownerUid));
    const profiles = await db.getAll(...profileRefs);
    const displayNameByUid = new Map(profiles.map((profile) => {
      const raw = profile.exists ? profile.get('displayName') : null;
      const displayName = typeof raw === 'string' && raw.trim()
        ? raw.trim().slice(0, 80)
        : 'Member';
      return [profile.id, displayName];
    }));

    const photos = await Promise.all(valid.map(async ({doc, ownerUid, storagePath}) => {
      const [previewUrl] = await getStorage().bucket().file(storagePath).getSignedUrl({
        action: 'read',
        expires: Date.now() + 2 * 60 * 1000,
      });
      return {
        photoId: doc.id,
        ownerUid,
        ownerDisplayName: displayNameByUid.get(ownerUid) ?? 'Member',
        previewUrl,
        expiresInSeconds: 120,
        createdAtMs: timestampMillis(doc.get('createdAt')),
        processedAtMs: timestampMillis(doc.get('processedAt')),
      };
    }));

    photos.sort((a, b) => (a.processedAtMs ?? a.createdAtMs ?? 0) - (b.processedAtMs ?? b.createdAtMs ?? 0));
    return {photos};
  },
);
