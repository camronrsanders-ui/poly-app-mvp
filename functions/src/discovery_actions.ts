import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

function requireTargetUid(raw: unknown, currentUid: string): string {
  const uid = String(raw ?? '').trim();
  if (!uid || uid === currentUid || uid.length > 128 || !/^[A-Za-z0-9:_-]+$/.test(uid)) {
    throw new HttpsError('invalid-argument', 'Invalid profile.');
  }
  return uid;
}

async function assertActive(db: FirebaseFirestore.Firestore, uid: string): Promise<void> {
  const user = await db.collection('users').doc(uid).get();
  if (!user.exists || user.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Account is not active.');
  }
}

async function consumeRateLimit(
  db: FirebaseFirestore.Firestore,
  uid: string,
): Promise<void> {
  const action = 'pass';
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
    if (count >= 300) {
      throw new HttpsError('resource-exhausted', 'Too many Pass actions. Try again later.');
    }
    tx.set(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

export const passProfile = onCall(
  {enforceAppCheck: true, maxInstances: 25},
  async (request) => {
    const db = getFirestore();
    const uid = requireUid(request.auth);
    const toUid = requireTargetUid(request.data?.toUid, uid);

    await assertActive(db, uid);
    // Charge the caller before inspecting the target so arbitrary UID probing
    // cannot bypass the abuse budget.
    await consumeRateLimit(db, uid);
    await assertActive(db, toUid);

    const passRef = db.collection('profile_passes').doc(`${uid}_${toUid}`);
    await passRef.set({
      passId: passRef.id,
      fromUid: uid,
      toUid,
      createdAt: FieldValue.serverTimestamp(),
    }, {merge: false});

    return {passed: true};
  },
);
