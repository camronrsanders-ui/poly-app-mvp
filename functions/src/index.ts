import {initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

initializeApp();
const db = getFirestore();

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

function pairIds(a: string, b: string) {
  const pair = [a, b].sort();
  return {a: pair[0], b: pair[1], id: `${pair[0]}_${pair[1]}`};
}

async function assertActive(uid: string) {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists || snap.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Account is not active.');
  }
}

async function blockedEitherWay(a: string, b: string): Promise<boolean> {
  const [ab, ba] = await Promise.all([
    db.collection('blocks').doc(`${a}_${b}`).get(),
    db.collection('blocks').doc(`${b}_${a}`).get(),
  ]);
  return ab.exists || ba.exists;
}

export const listDiscoveryCandidates = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const uid = requireUid(request.auth);
    await assertActive(uid);

    const limitRaw = Number(request.data?.limit ?? 20);
    const limit = Math.max(1, Math.min(50, Number.isFinite(limitRaw) ? limitRaw : 20));

    const [outgoingBlocks, incomingBlocks, outgoingLikes] = await Promise.all([
      db.collection('blocks').where('blockerUid', '==', uid).get(),
      db.collection('blocks').where('blockedUid', '==', uid).get(),
      db.collection('likes').where('fromUid', '==', uid).get(),
    ]);

    const excluded = new Set<string>([uid]);
    outgoingBlocks.forEach((d) => excluded.add(String(d.get('blockedUid') ?? '')));
    incomingBlocks.forEach((d) => excluded.add(String(d.get('blockerUid') ?? '')));
    outgoingLikes.forEach((d) => excluded.add(String(d.get('toUid') ?? '')));

    // Fetch a bounded candidate pool and filter privately on the trusted backend.
    const profilePool = await db.collection('profiles')
      .where('profileVisibility', '==', 'public')
      .where('openToConnections', '==', true)
      .limit(Math.min(150, limit * 5))
      .get();

    const candidates: Record<string, unknown>[] = [];
    for (const doc of profilePool.docs) {
      if (candidates.length >= limit) break;
      if (excluded.has(doc.id)) continue;

      const account = await db.collection('users').doc(doc.id).get();
      if (!account.exists || account.get('accountStatus') !== 'active') continue;

      const data = doc.data();
      // Return only public discovery fields. Do not return private preference data.
      candidates.push({
        uid: doc.id,
        displayName: data.displayName ?? '',
        age: data.age ?? null,
        city: data.city ?? '',
        region: data.region ?? '',
        bio: data.bio ?? '',
        headline: data.headline ?? '',
        avatarUrl: data.avatarUrl ?? '',
        photoUrls: Array.isArray(data.photoUrls) ? data.photoUrls.slice(0, 6) : [],
        genderIdentity: data.genderIdentity ?? '',
        pronouns: data.pronouns ?? '',
        orientation: data.orientation ?? '',
        relationshipStructure: data.relationshipStructure ?? '',
        relationshipStatus: data.relationshipStatus ?? '',
        partnered: data.partnered === true,
        intentionTags: Array.isArray(data.intentionTags) ? data.intentionTags : [],
        interests: Array.isArray(data.interests) ? data.interests : [],
        lookingForNote: data.lookingForNote ?? '',
      });
    }

    return {candidates};
  },
);

export const likeUser = onCall(
  {enforceAppCheck: true, maxInstances: 30},
  async (request) => {
    const fromUid = requireUid(request.auth);
    const toUid = String(request.data?.toUid ?? '').trim();
    if (!toUid || toUid === fromUid) {
      throw new HttpsError('invalid-argument', 'Invalid target user.');
    }

    await Promise.all([assertActive(fromUid), assertActive(toUid)]);
    if (await blockedEitherWay(fromUid, toUid)) {
      throw new HttpsError('permission-denied', 'Interaction is unavailable.');
    }

    const likeRef = db.collection('likes').doc(`${fromUid}_${toUid}`);
    const reverseRef = db.collection('likes').doc(`${toUid}_${fromUid}`);
    const pair = pairIds(fromUid, toUid);
    const matchRef = db.collection('matches').doc(pair.id);

    const matched = await db.runTransaction(async (tx) => {
      const [existingLike, reverseLike, existingMatch] = await Promise.all([
        tx.get(likeRef),
        tx.get(reverseRef),
        tx.get(matchRef),
      ]);

      if (!existingLike.exists) {
        tx.create(likeRef, {
          fromUid,
          toUid,
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      const isMutual = reverseLike.exists;
      if (isMutual && !existingMatch.exists) {
        tx.create(matchRef, {
          userAUid: pair.a,
          userBUid: pair.b,
          createdAt: FieldValue.serverTimestamp(),
          active: true,
        });
      }
      return isMutual || existingMatch.exists;
    });

    return {matched, matchId: matched ? pair.id : null};
  },
);

export const ensureConversation = onCall(
  {enforceAppCheck: true, maxInstances: 30},
  async (request) => {
    const currentUid = requireUid(request.auth);
    const otherUid = String(request.data?.otherUid ?? '').trim();
    if (!otherUid || otherUid === currentUid) {
      throw new HttpsError('invalid-argument', 'Invalid participant.');
    }

    await Promise.all([assertActive(currentUid), assertActive(otherUid)]);
    if (await blockedEitherWay(currentUid, otherUid)) {
      throw new HttpsError('permission-denied', 'Conversation is unavailable.');
    }

    const pair = pairIds(currentUid, otherUid);
    const matchRef = db.collection('matches').doc(pair.id);
    const conversationRef = db.collection('conversations').doc(pair.id);

    await db.runTransaction(async (tx) => {
      const [match, conversation] = await Promise.all([
        tx.get(matchRef),
        tx.get(conversationRef),
      ]);

      if (!match.exists || match.get('active') !== true) {
        throw new HttpsError('failed-precondition', 'An active match is required.');
      }

      if (!conversation.exists) {
        tx.create(conversationRef, {
          participantUids: [pair.a, pair.b],
          createdAt: FieldValue.serverTimestamp(),
          lastMessageAt: FieldValue.serverTimestamp(),
          active: true,
        });
      }
    });

    return {conversationId: pair.id};
  },
);
