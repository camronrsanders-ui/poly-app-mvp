import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {FieldValue, Timestamp, getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
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

function requireTargetUid(raw: unknown, currentUid: string): string {
  const uid = String(raw ?? '').trim();
  if (!uid || uid.length > 128 || uid === currentUid) {
    throw new HttpsError('invalid-argument', 'Invalid target user.');
  }
  return uid;
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

async function consumeRateLimit(
  uid: string,
  action: string,
  maxRequests: number,
  windowMs: number,
): Promise<void> {
  const now = Date.now();
  const ref = db.collection('_rate_limits').doc(`${action}_${uid}`);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const currentStart = snap.exists ? snap.get('windowStart') : null;
    const startMs = currentStart instanceof Timestamp ? currentStart.toMillis() : 0;
    const currentCount = snap.exists ? Number(snap.get('count') ?? 0) : 0;

    if (!snap.exists || now - startMs >= windowMs) {
      tx.set(ref, {
        uid,
        action,
        count: 1,
        windowStart: Timestamp.fromMillis(now),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    if (currentCount >= maxRequests) {
      throw new HttpsError('resource-exhausted', 'Please wait a moment and try again.');
    }

    tx.update(ref, {
      count: currentCount + 1,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

export const listDiscoveryCandidates = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const uid = requireUid(request.auth);
    await Promise.all([
      assertActive(uid),
      consumeRateLimit(uid, 'discover', 60, 60_000),
    ]);

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

    const profilePool = await db.collection('profiles')
      .where('profileVisibility', '==', 'public')
      .where('openToConnections', '==', true)
      .limit(Math.min(150, limit * 5))
      .get();

    const eligibleProfiles = profilePool.docs.filter((doc) => !excluded.has(doc.id));
    const accountRefs = eligibleProfiles.map((doc) => db.collection('users').doc(doc.id));
    const accountSnaps = accountRefs.length > 0 ? await db.getAll(...accountRefs) : [];
    const activeIds = new Set(
      accountSnaps
        .filter((snap) => snap.exists && snap.get('accountStatus') === 'active')
        .map((snap) => snap.id),
    );

    const candidates: Record<string, unknown>[] = [];
    for (const doc of eligibleProfiles) {
      if (candidates.length >= limit) break;
      if (!activeIds.has(doc.id)) continue;

      const data = doc.data();
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
        intentionTags: Array.isArray(data.intentionTags) ? data.intentionTags.slice(0, 12) : [],
        interests: Array.isArray(data.interests) ? data.interests.slice(0, 20) : [],
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
    const toUid = requireTargetUid(request.data?.toUid, fromUid);

    await Promise.all([
      assertActive(fromUid),
      assertActive(toUid),
      consumeRateLimit(fromUid, 'like', 30, 60_000),
    ]);
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
    const otherUid = requireTargetUid(request.data?.otherUid, currentUid);

    await Promise.all([
      assertActive(currentUid),
      assertActive(otherUid),
      consumeRateLimit(currentUid, 'conversation', 20, 60_000),
    ]);
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

export const deleteMyAccount = onCall(
  {enforceAppCheck: true, maxInstances: 5},
  async (request) => {
    const uid = requireUid(request.auth);
    if (String(request.data?.confirmation ?? '') !== 'DELETE') {
      throw new HttpsError('invalid-argument', 'Explicit deletion confirmation is required.');
    }

    const authTime = Number(request.auth?.token?.auth_time ?? 0) * 1000;
    if (!authTime || Date.now() - authTime > 10 * 60_000) {
      throw new HttpsError('failed-precondition', 'Please sign in again before deleting your account.');
    }

    await consumeRateLimit(uid, 'delete_account', 2, 24 * 60 * 60_000);

    const userRef = db.collection('users').doc(uid);
    await userRef.set({
      accountStatus: 'paused',
      deletionRequestedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    const [
      cards,
      outgoingLikes,
      incomingLikes,
      matchesA,
      matchesB,
      conversations,
      sentMessages,
      outgoingBlocks,
      incomingBlocks,
      privateMedia,
      grantsOwned,
      grantsReceived,
      requestsFrom,
      requestsTo,
      reportsFrom,
      reportsAgainst,
    ] = await Promise.all([
      db.collection('relationship_cards').where('ownerUid', '==', uid).get(),
      db.collection('likes').where('fromUid', '==', uid).get(),
      db.collection('likes').where('toUid', '==', uid).get(),
      db.collection('matches').where('userAUid', '==', uid).get(),
      db.collection('matches').where('userBUid', '==', uid).get(),
      db.collection('conversations').where('participantUids', 'array-contains', uid).get(),
      db.collection('messages').where('senderUid', '==', uid).get(),
      db.collection('blocks').where('blockerUid', '==', uid).get(),
      db.collection('blocks').where('blockedUid', '==', uid).get(),
      db.collection('private_media').where('ownerUid', '==', uid).get(),
      db.collection('private_media_grants').where('ownerUid', '==', uid).get(),
      db.collection('private_media_grants').where('recipientUid', '==', uid).get(),
      db.collection('private_media_requests').where('requesterUid', '==', uid).get(),
      db.collection('private_media_requests').where('recipientUid', '==', uid).get(),
      db.collection('reports').where('reporterUid', '==', uid).get(),
      db.collection('reports').where('reportedUid', '==', uid).get(),
    ]);

    const writer = db.bulkWriter();
    const seenDeletePaths = new Set<string>();
    const deleteDocs = (docs: FirebaseFirestore.QueryDocumentSnapshot[]) => {
      for (const doc of docs) {
        if (seenDeletePaths.has(doc.ref.path)) continue;
        seenDeletePaths.add(doc.ref.path);
        writer.delete(doc.ref);
      }
    };

    deleteDocs(cards.docs);
    deleteDocs(outgoingLikes.docs);
    deleteDocs(incomingLikes.docs);
    deleteDocs(sentMessages.docs);
    deleteDocs(outgoingBlocks.docs);
    deleteDocs(incomingBlocks.docs);
    deleteDocs(privateMedia.docs);
    deleteDocs(grantsOwned.docs);
    deleteDocs(grantsReceived.docs);
    deleteDocs(requestsFrom.docs);
    deleteDocs(requestsTo.docs);

    for (const doc of [...matchesA.docs, ...matchesB.docs]) {
      writer.set(doc.ref, {active: false, endedAt: FieldValue.serverTimestamp()}, {merge: true});
    }
    for (const doc of conversations.docs) {
      writer.set(doc.ref, {active: false, lastMessageAt: FieldValue.serverTimestamp()}, {merge: true});
    }

    for (const doc of reportsFrom.docs) {
      writer.set(doc.ref, {reporterUid: '[deleted]'}, {merge: true});
    }
    for (const doc of reportsAgainst.docs) {
      writer.set(doc.ref, {reportedUid: '[deleted]'}, {merge: true});
    }

    writer.delete(db.collection('profiles').doc(uid));
    writer.delete(db.collection('_rate_limits').doc(`discover_${uid}`));
    writer.delete(db.collection('_rate_limits').doc(`like_${uid}`));
    writer.delete(db.collection('_rate_limits').doc(`conversation_${uid}`));
    await writer.close();

    const bucket = getStorage().bucket();
    await Promise.all([
      bucket.deleteFiles({prefix: `users/${uid}/profile/`}).catch(() => undefined),
      bucket.deleteFiles({prefix: `private_media/${uid}/`}).catch(() => undefined),
    ]);

    await userRef.delete();
    await getAuth().deleteUser(uid);

    return {deleted: true};
  },
);

export {blockUser, unblockUser} from './safety';
export {
  grantPrivateMedia,
  revokePrivateMedia,
  getPrivateMediaAccess,
} from './private_vault';
