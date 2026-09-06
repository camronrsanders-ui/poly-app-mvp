import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {
  assertActiveCompliantMember,
  isActiveCompliantMember,
} from './account_compliance';

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

function pairId(a: string, b: string): string {
  return [a, b].sort().join('_');
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

    await assertActiveCompliantMember(db, uid);
    // Charge the caller before inspecting the target so arbitrary UID probing
    // cannot bypass the abuse budget.
    await consumeRateLimit(db, uid);

    const callerUserRef = db.collection('users').doc(uid);
    const targetUserRef = db.collection('users').doc(toUid);
    const passRef = db.collection('profile_passes').doc(`${uid}_${toUid}`);
    const likeRef = db.collection('likes').doc(`${uid}_${toUid}`);
    const matchRef = db.collection('matches').doc(pairId(uid, toUid));

    await db.runTransaction(async (tx) => {
      const [callerUser, targetUser, existingLike, existingPass, existingMatch] = await Promise.all([
        tx.get(callerUserRef),
        tx.get(targetUserRef),
        tx.get(likeRef),
        tx.get(passRef),
        tx.get(matchRef),
      ]);

      if (!isActiveCompliantMember(callerUser)) {
        throw new HttpsError('permission-denied', 'Complete adult access before using Discover.');
      }
      if (!isActiveCompliantMember(targetUser)) {
        throw new HttpsError('permission-denied', 'Profile is unavailable.');
      }
      // Passing is a discovery action, not a connection-ending action. Direct
      // calls cannot create Pass state for a current or former connection.
      if (existingMatch.exists) {
        throw new HttpsError('failed-precondition', 'This profile is not available in discovery.');
      }

      // Like and Pass both read the opposing state before writing. Firestore
      // transaction retries therefore make concurrent explicit actions resolve
      // without leaving both documents behind; the last successful action wins.
      if (existingLike.exists) tx.delete(likeRef);
      tx.set(passRef, {
        passId: passRef.id,
        fromUid: uid,
        toUid,
        createdAt: FieldValue.serverTimestamp(),
      }, {merge: false});
      void existingPass;
    });

    return {passed: true};
  },
);
