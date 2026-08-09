import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

initializeApp();

const db = getFirestore();

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

async function assertActive(uid: string) {
  const user = await db.collection('users').doc(uid).get();
  if (!user.exists || user.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Account is not active.');
  }
}

function pairId(a: string, b: string): string {
  return [a, b].sort().join('_');
}

async function isBlocked(a: string, b: string): Promise<boolean> {
  const [ab, ba] = await Promise.all([
    db.collection('blocks').doc(`${a}_${b}`).get(),
    db.collection('blocks').doc(`${b}_${a}`).get(),
  ]);
  return ab.exists || ba.exists;
}

async function consumeRateLimit(uid: string, action: string, max: number, windowMs: number) {
  const ref = db.collection('_rate_limits').doc(`${action}_${uid}`);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const start = Number(snap.get('windowStartMs') ?? 0);
    const count = Number(snap.get('count') ?? 0);
    if (!snap.exists || now - start >= windowMs) {
      tx.set(ref, {uid, action, windowStartMs: now, count: 1, updatedAt: FieldValue.serverTimestamp()});
      return;
    }
    if (count >= max) throw new HttpsError('resource-exhausted', 'Too many requests. Try again later.');
    tx.set(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

export const getDiscoverCandidates = onCall(
  {enforceAppCheck: true, maxInstances: 25},
  async (request) => {
    const uid = requireUid(request.auth);
    await assertActive(uid);
    await consumeRateLimit(uid, 'discover', 60, 60_000);

    const limit = Math.min(Math.max(Number(request.data?.limit ?? 20), 1), 40);
    const profileSnap = await db.collection('profiles').doc(uid).get();
    if (!profileSnap.exists) throw new HttpsError('failed-precondition', 'Complete your profile first.');

    const profiles = await db.collection('profiles')
      .where('profileVisibility', '==', 'public')
      .limit(limit + 20)
      .get();

    const candidateIds = profiles.docs.map((doc) => doc.id).filter((id) => id !== uid);
    const userRefs = candidateIds.map((id) => db.collection('users').doc(id));
    const userSnaps = userRefs.length ? await db.getAll(...userRefs) : [];
    const active = new Set(userSnaps.filter((snap) => snap.exists && snap.get('accountStatus') === 'active').map((snap) => snap.id));

    const output: FirebaseFirestore.DocumentData[] = [];
    for (const doc of profiles.docs) {
      if (doc.id === uid || !active.has(doc.id)) continue;
      if (await isBlocked(uid, doc.id)) continue;
      output.push(doc.data());
      if (output.length >= limit) break;
    }
    return {profiles: output};
  },
);

export const likeProfile = onCall(
  {enforceAppCheck: true, maxInstances: 25},
  async (request) => {
    const uid = requireUid(request.auth);
    const toUid = String(request.data?.toUid ?? '').trim();
    if (!toUid || toUid === uid || toUid.length > 128) throw new HttpsError('invalid-argument', 'Invalid target user.');
    await assertActive(uid);
    await assertActive(toUid);
    await consumeRateLimit(uid, 'like', 120, 60 * 60_000);
    if (await isBlocked(uid, toUid)) throw new HttpsError('permission-denied', 'Interaction unavailable.');

    const likeRef = db.collection('likes').doc(`${uid}_${toUid}`);
    const reverseRef = db.collection('likes').doc(`${toUid}_${uid}`);
    const matchRef = db.collection('matches').doc(pairId(uid, toUid));

    const matched = await db.runTransaction(async (tx) => {
      const reverse = await tx.get(reverseRef);
      tx.set(likeRef, {likeId: likeRef.id, fromUid: uid, toUid, createdAt: FieldValue.serverTimestamp()});
      if (!reverse.exists) return false;
      const [userAUid, userBUid] = [uid, toUid].sort();
      tx.set(matchRef, {matchId: matchRef.id, userAUid, userBUid, createdAt: FieldValue.serverTimestamp(), active: true}, {merge: true});
      return true;
    });
    return {liked: true, matched, matchId: matched ? matchRef.id : null};
  },
);

export const createConversation = onCall(
  {enforceAppCheck: true, maxInstances: 25},
  async (request) => {
    const uid = requireUid(request.auth);
    const otherUid = String(request.data?.otherUid ?? '').trim();
    if (!otherUid || otherUid === uid || otherUid.length > 128) throw new HttpsError('invalid-argument', 'Invalid participant.');
    await assertActive(uid);
    await assertActive(otherUid);
    await consumeRateLimit(uid, 'conversation', 30, 60 * 60_000);
    if (await isBlocked(uid, otherUid)) throw new HttpsError('permission-denied', 'Interaction unavailable.');

    const id = pairId(uid, otherUid);
    const match = await db.collection('matches').doc(id).get();
    if (!match.exists || match.get('active') !== true) throw new HttpsError('failed-precondition', 'An active match is required.');

    const ref = db.collection('conversations').doc(id);
    const participantUids = [uid, otherUid].sort();
    await ref.set({conversationId: id, participantUids, createdAt: FieldValue.serverTimestamp(), lastMessageAt: FieldValue.serverTimestamp(), active: true}, {merge: true});
    return {conversationId: id};
  },
);

export const deleteMyAccount = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    const uid = requireUid(request.auth);
    if (String(request.data?.confirmation ?? '') !== 'DELETE') {
      throw new HttpsError('invalid-argument', 'Type DELETE to confirm account deletion.');
    }

    const authTime = Number(request.auth?.token?.auth_time ?? 0) * 1000;
    if (!authTime || Date.now() - authTime > 10 * 60_000) {
      throw new HttpsError('failed-precondition', 'Please sign in again before deleting your account.');
    }

    await consumeRateLimit(uid, 'delete_account', 2, 24 * 60 * 60_000);

    const userRef = db.collection('users').doc(uid);
    await userRef.set({accountStatus: 'paused', deletionRequestedAt: FieldValue.serverTimestamp()}, {merge: true});

    const [
      cards, outgoingLikes, incomingLikes, matchesA, matchesB, conversations,
      sentMessages, outgoingBlocks, incomingBlocks, privateMedia, grantsOwned,
      grantsReceived, requestsFrom, requestsTo, preferencesAsRecipient,
      preferencesAsRequester, reportsFrom, reportsAgainst, profileMedia,
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
      db.collection('private_media_request_preferences').where('recipientUid', '==', uid).get(),
      db.collection('private_media_request_preferences').where('requesterUid', '==', uid).get(),
      db.collection('reports').where('reporterUid', '==', uid).get(),
      db.collection('reports').where('reportedUid', '==', uid).get(),
      db.collection('profile_media').where('ownerUid', '==', uid).get(),
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
    deleteDocs(preferencesAsRecipient.docs);
    deleteDocs(preferencesAsRequester.docs);
    deleteDocs(profileMedia.docs);

    for (const doc of [...matchesA.docs, ...matchesB.docs]) {
      writer.set(doc.ref, {active: false, endedAt: FieldValue.serverTimestamp()}, {merge: true});
    }
    for (const doc of conversations.docs) {
      writer.set(doc.ref, {active: false, lastMessageAt: FieldValue.serverTimestamp()}, {merge: true});
    }
    for (const doc of reportsFrom.docs) writer.set(doc.ref, {reporterUid: '[deleted]'}, {merge: true});
    for (const doc of reportsAgainst.docs) writer.set(doc.ref, {reportedUid: '[deleted]'}, {merge: true});

    writer.delete(db.collection('profiles').doc(uid));
    for (const action of [
      'discover', 'like', 'conversation', 'delete_account', 'block', 'unblock',
      'unmatch', 'report', 'private_media_request', 'private_media_request_response',
      'private_media_grant', 'private_media_revoke', 'private_media_access',
      'private_media_report', 'profile_photo_upload',
    ]) {
      writer.delete(db.collection('_rate_limits').doc(`${action}_${uid}`));
    }
    await writer.close();

    const bucket = getStorage().bucket();
    await Promise.all([
      bucket.deleteFiles({prefix: `users/${uid}/profile/`}).catch(() => undefined),
      bucket.deleteFiles({prefix: `users/${uid}/profile_quarantine/`}).catch(() => undefined),
      bucket.deleteFiles({prefix: `private_media/${uid}/`}).catch(() => undefined),
    ]);

    await userRef.delete();
    await getAuth().deleteUser(uid);
    return {deleted: true};
  },
);

export {blockUser, unblockUser, endConnection, submitReport} from './safety';
export {
  requestPrivateMedia,
  respondToPrivateMediaRequest,
  clearPrivateMediaRequestPreference,
  grantPrivateMedia,
  revokePrivateMedia,
  getPrivateMediaAccess,
  reportPrivateMedia,
} from './private_vault';
export {
  beginProfilePhotoUpload,
  confirmProfilePhotoUpload,
  processProfilePhoto,
  reviewProfilePhoto,
  getProfilePhotoAccess,
  deleteProfilePhoto,
} from './profile_media';
export {listMyProfilePhotos} from './profile_media_listing';
