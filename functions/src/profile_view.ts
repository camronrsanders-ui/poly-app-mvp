import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {
  assertActiveCompliantMember,
  isActiveCompliantMember,
} from './account_compliance';
import {toProfileView} from './profile_view_fields';

const db = getFirestore();
const maxConnectionsPerResponse = 100;

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
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

function otherUidFromBlock(uid: string, snap: FirebaseFirestore.DocumentSnapshot): string | null {
  if (!snap.exists) return null;
  const blockerUid = String(snap.get('blockerUid') ?? '');
  const blockedUid = String(snap.get('blockedUid') ?? '');
  if (blockerUid === uid && blockedUid) return blockedUid;
  if (blockedUid === uid && blockerUid) return blockerUid;
  return null;
}

export const listMyConnections = onCall(
  {enforceAppCheck: true, maxInstances: 25},
  async (request) => {
    const uid = requireUid(request.auth);
    await assertActiveCompliantMember(db, uid);
    await consumeRateLimit(uid, 60, 60_000);

    // Filter active state in Firestore before applying the read cap. Limiting a
    // user's entire historical match set first could hide current connections
    // after enough old matches accumulated.
    const [asA, asB] = await Promise.all([
      db.collection('matches')
        .where('userAUid', '==', uid)
        .where('active', '==', true)
        .limit(maxConnectionsPerResponse)
        .get(),
      db.collection('matches')
        .where('userBUid', '==', uid)
        .where('active', '==', true)
        .limit(maxConnectionsPerResponse)
        .get(),
    ]);

    const seen = new Set<string>();
    const records: Array<{match: FirebaseFirestore.QueryDocumentSnapshot; otherUid: string}> = [];
    for (const match of [...asA.docs, ...asB.docs]) {
      // Keep this defensive check even though the query is already active-only.
      if (match.get('active') !== true) continue;
      const data = match.data();
      const otherUid = data.userAUid === uid
        ? String(data.userBUid ?? '')
        : String(data.userAUid ?? '');
      if (!otherUid || otherUid === uid || seen.has(otherUid)) continue;
      seen.add(otherUid);
      records.push({match, otherUid});
      if (records.length >= maxConnectionsPerResponse) break;
    }

    if (records.length === 0) return {connections: []};

    const userRefs = records.map(({otherUid}) => db.collection('users').doc(otherUid));
    const profileRefs = records.map(({otherUid}) => db.collection('profiles').doc(otherUid));
    const conversationRefs = records.map(({match}) => db.collection('conversations').doc(match.id));
    const blockRefs = records.flatMap(({otherUid}) => [
      db.collection('blocks').doc(`${uid}_${otherUid}`),
      db.collection('blocks').doc(`${otherUid}_${uid}`),
    ]);

    // Batch all per-connection reads. The previous one-at-a-time loop amplified
    // network latency and made large connection lists much more failure-prone.
    const [users, profiles, conversations, blocks] = await Promise.all([
      db.getAll(...userRefs),
      db.getAll(...profileRefs),
      db.getAll(...conversationRefs),
      db.getAll(...blockRefs),
    ]);

    const userById = new Map(users.map((snap) => [snap.id, snap]));
    const profileById = new Map(profiles.map((snap) => [snap.id, snap]));
    const conversationById = new Map(conversations.map((snap) => [snap.id, snap]));
    const blocked = new Set(
      blocks
        .map((snap) => otherUidFromBlock(uid, snap))
        .filter((value): value is string => value !== null),
    );

    const output: FirebaseFirestore.DocumentData[] = [];
    for (const {match, otherUid} of records) {
      if (blocked.has(otherUid)) continue;
      const user = userById.get(otherUid);
      const profile = profileById.get(otherUid);
      if (!user || !isActiveCompliantMember(user) || !profile?.exists) continue;

      const conversation = conversationById.get(match.id);
      const conversationActive = conversation?.exists === true && conversation.get('active') === true;
      const lastMessageAt = conversationActive ? conversation?.get('lastMessageAt') : null;
      const lastMessageAtMs = typeof lastMessageAt?.toMillis === 'function'
        ? Number(lastMessageAt.toMillis())
        : null;

      output.push({
        ...toProfileView(otherUid, profile.data()!),
        matchId: match.id,
        conversationId: conversationActive ? conversation?.id : null,
        lastMessageAtMs,
      });
    }

    output.sort((a, b) => Number(b.lastMessageAtMs ?? 0) - Number(a.lastMessageAtMs ?? 0));
    return {connections: output};
  },
);
