import {randomUUID} from 'node:crypto';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {canViewOwnerProfile} from './profile_access';

const db = getFirestore();

function runningInFunctionsEmulator(): boolean {
  return process.env.FUNCTIONS_EMULATOR === 'true';
}

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

function requireOwnerUid(raw: unknown): string {
  const uid = String(raw ?? '').trim();
  if (!uid || uid.length > 128 || !/^[A-Za-z0-9_-]+$/.test(uid)) {
    throw new HttpsError('invalid-argument', 'Invalid profile owner.');
  }
  return uid;
}

export const listMyProfilePhotos = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const uid = requireUid(request.auth);
    await Promise.all([assertActive(uid), consumeRateLimit(uid)]);

    const requestedOwner = String(request.data?.ownerUid ?? '').trim();
    const ownerUid = requestedOwner ? requireOwnerUid(requestedOwner) : uid;
    const viewingAnotherProfile = ownerUid !== uid;

    if (viewingAnotherProfile && !(await canViewOwnerProfile(db, uid, ownerUid))) {
      throw new HttpsError('permission-denied', 'Profile photos are unavailable.');
    }

    const snapshot = await db.collection('profile_media')
      .where('ownerUid', '==', ownerUid)
      .limit(20)
      .get();

    if (viewingAnotherProfile) {
      const activeDocs = snapshot.docs
        .filter((doc) => doc.get('status') === 'active')
        .sort((a, b) => (timestampMillis(b.get('createdAt')) ?? 0) - (timestampMillis(a.get('createdAt')) ?? 0));

      const bucket = getStorage().bucket();
      const photos = (await Promise.all(activeDocs.map(async (doc) => {
        const expectedPath = `users/${ownerUid}/profile/${doc.id}.jpg`;
        const storagePath = String(doc.get('storagePath') ?? '');
        if (storagePath !== expectedPath) return null;
        try {
          const file = bucket.file(storagePath);

          if (runningInFunctionsEmulator()) {
            const token = randomUUID();

            const [currentMetadata] = await file.getMetadata();
            await file.setMetadata({
              metadata: {
                ...(currentMetadata.metadata ?? {}),
                firebaseStorageDownloadTokens: token,
              },
            });

            const requestedHost = String(
              request.data?.emulatorHost ?? '127.0.0.1',
            ).trim();

            const emulatorHost =
              requestedHost === '127.0.0.1'
              || requestedHost === 'localhost'
              || requestedHost === '10.0.2.2'
                ? requestedHost
                : '127.0.0.1';

            const encodedBucket = encodeURIComponent(bucket.name);
            const encodedPath = encodeURIComponent(storagePath);
            const encodedToken = encodeURIComponent(token);

            const url =
              `http://${emulatorHost}:9199/v0/b/${encodedBucket}/o/`
              + `${encodedPath}?alt=media&token=${encodedToken}`;

            return {
              photoId: doc.id,
              url,
              expiresInSeconds: 0,
              createdAtMs: timestampMillis(doc.get('createdAt')),
            };
          }

          const [url] = await file.getSignedUrl({
            action: 'read',
            expires: Date.now() + 2 * 60 * 1000,
          });

          return {
            photoId: doc.id,
            url,
            expiresInSeconds: 120,
            createdAtMs: timestampMillis(doc.get('createdAt')),
          };
        } catch (_) {
          // Never expose a raw path or fail the entire profile because one
          // approved object is temporarily unavailable.
          return null;
        }
      }))).filter((photo): photo is NonNullable<typeof photo> => photo !== null);

      return {photos};
    }

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
