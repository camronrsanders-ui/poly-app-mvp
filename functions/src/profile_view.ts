import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {toProfileView} from './profile_view_fields';

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

async function consumeRateLimit(uid: string, max: number, windowMs: number): Promise<void> {
  const action = 'connections_list';
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
      throw new HttpsError('resource-exhausted', 'Too many requests. Try again later.');
    }
    tx.set(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

async function isBlocked(a: string, b: string): Promise<boolean> {
  const [ab, ba] = await Promise.all([
    db.collection('blocks').doc(`${a}_${b}`).get(),
    db.collection('blocks').doc(`${b}_${a}`).get(),
  ]);
  return ab.exists || ba.exists;
}

export const listMyConnections = onCall(
  {enforceAppCheck: true, maxInstances: 25},
  async (request) => {
    const uid = requireUid(request.auth);
    await assertActive(uid);
    await consumeRateLimit(uid, 60, 60_000);

    // Query each participant field separately and filter active state in trusted
    // code. This avoids requiring a composite index just to list connections.
    const [asA, asB] = await Promise.all([
      db.collection('matches')
        .where('userAUid', '==', uid)
        .limit(150)
        .get(),
      db.collection('matches')
        .where('userBUid', '==', uid)
        .limit(150)
        .get(),
    ]);

    const matches = [...asA.docs, ...asB.docs].filter((match) => match.get('active') === true);
    const seen = new Set<string>();
    const output: FirebaseFirestore.DocumentData[] = [];

    for (const match of matches) {
      const data = match.data();
      const otherUid = data.userAUid === uid
        ? String(data.userBUid ?? '')
        : String(data.userAUid ?? '');
      if (!otherUid || seen.has(otherUid)) continue;
      seen.add(otherUid);

      if (await isBlocked(uid, otherUid)) continue;
      const [user, profile, conversation] = await Promise.all([
        db.collection('users').doc(otherUid).get(),
        db.collection('profiles').doc(otherUid).get(),
        db.collection('conversations').doc(match.id).get(),
      ]);
      if (!user.exists || user.get('accountStatus') !== 'active' || !profile.exists) continue;

      const conversationActive = conversation.exists && conversation.get('active') === true;
      const lastMessageAt = conversationActive ? conversation.get('lastMessageAt') : null;
      const lastMessageAtMs = typeof lastMessageAt?.toMillis === 'function'
        ? Number(lastMessageAt.toMillis())
        : null;

      output.push({
        ...toProfileView(otherUid, profile.data()!),
        matchId: match.id,
        conversationId: conversationActive ? conversation.id : null,
        lastMessageAtMs,
      });
    }

    return {connections: output};
  },
);
