import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

const db = getFirestore();
const action = 'conversation_list';

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
      throw new HttpsError('resource-exhausted', 'Too many conversation-list requests. Try again later.');
    }
    tx.set(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

function pairId(a: string, b: string): string {
  return [a, b].sort().join('_');
}

async function pairIsEligible(a: string, b: string): Promise<boolean> {
  const [user, profile, blockAB, blockBA, match] = await Promise.all([
    db.collection('users').doc(b).get(),
    db.collection('profiles').doc(b).get(),
    db.collection('blocks').doc(`${a}_${b}`).get(),
    db.collection('blocks').doc(`${b}_${a}`).get(),
    db.collection('matches').doc(pairId(a, b)).get(),
  ]);
  return user.exists
    && user.get('accountStatus') === 'active'
    && profile.exists
    && !blockAB.exists
    && !blockBA.exists
    && match.exists
    && match.get('active') === true;
}

function timestampMillis(value: unknown): number | null {
  const candidate = value as {toMillis?: () => number} | null | undefined;
  return candidate?.toMillis?.() ?? null;
}

export const listMyConversationSummaries = onCall(
  {enforceAppCheck: true, maxInstances: 25},
  async (request) => {
    const uid = requireUid(request.auth);
    await Promise.all([assertActive(uid), consumeRateLimit(uid)]);

    const snapshot = await db.collection('conversations')
      .where('participantUids', 'array-contains', uid)
      .limit(50)
      .get();

    const conversations: FirebaseFirestore.DocumentData[] = [];
    for (const conversation of snapshot.docs) {
      if (conversation.get('active') !== true) continue;
      const participants = conversation.get('participantUids');
      if (!Array.isArray(participants) || participants.length !== 2) continue;
      const participantUids = participants.filter((value): value is string => typeof value === 'string');
      if (participantUids.length !== 2 || !participantUids.includes(uid)) continue;

      const otherUid = participantUids.find((value) => value !== uid);
      if (!otherUid || !(await pairIsEligible(uid, otherUid))) continue;

      const profile = await db.collection('profiles').doc(otherUid).get();
      if (!profile.exists) continue;
      conversations.push({
        conversationId: conversation.id,
        otherUid,
        otherDisplayName: String(profile.get('displayName') ?? 'Connection').slice(0, 80),
        relationshipStructure: String(profile.get('relationshipStructure') ?? '').slice(0, 120),
        lastMessageAtMs: timestampMillis(conversation.get('lastMessageAt')),
      });
    }

    conversations.sort((a, b) => Number(b.lastMessageAtMs ?? 0) - Number(a.lastMessageAtMs ?? 0));
    return {conversations};
  },
);
