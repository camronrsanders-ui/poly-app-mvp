import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {
  assertActiveCompliantMember,
  isActiveCompliantMember,
} from './account_compliance';
import {assertCanReceiveNewConnection} from './connection_eligibility';
import {candidateMatchesPreferences} from './discovery_preferences';
import {toProfileView} from './profile_view_fields';

initializeApp();

const db = getFirestore();

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

async function assertActive(uid: string) {
  await assertActiveCompliantMember(db, uid);
}

function pairId(a: string, b: string): string {
  return [a, b].sort().join('_');
}

function blockedPeersFromSnapshots(
  uid: string,
  snapshots: FirebaseFirestore.DocumentSnapshot[],
): Set<string> {
  const blocked = new Set<string>();
  for (const snap of snapshots) {
    if (!snap.exists) continue;
    const blockerUid = String(snap.get('blockerUid') ?? '');
    const blockedUid = String(snap.get('blockedUid') ?? '');
    if (blockerUid === uid && blockedUid) blocked.add(blockedUid);
    if (blockedUid === uid && blockerUid) blocked.add(blockerUid);
  }
  return blocked;
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

    const requestedLimit = Number(request.data?.limit ?? 20);
    const limit = Number.isFinite(requestedLimit)
      ? Math.min(Math.max(Math.trunc(requestedLimit), 1), 40)
      : 20;
    const profileSnap = await db.collection('profiles').doc(uid).get();
    if (!profileSnap.exists) throw new HttpsError('failed-precondition', 'Complete your profile first.');
    const requesterProfile = profileSnap.data()!;

    // Scan a bounded pool because private age/structure/intention preferences
    // are applied in trusted code rather than exposed in client-readable data.
    const scanLimit = Math.min(Math.max(limit * 4, limit + 20), 120);
    const profiles = await db.collection('profiles')
      .where('profileVisibility', '==', 'public')
      .where('openToConnections', '==', true)
      .limit(scanLimit)
      .get();

    const candidateIds = profiles.docs.map((doc) => doc.id).filter((id) => id !== uid);
    const userRefs = candidateIds.map((id) => db.collection('users').doc(id));
    const passRefs = candidateIds.map((id) => db.collection('profile_passes').doc(`${uid}_${id}`));
    const outgoingLikeRefs = candidateIds.map((id) => db.collection('likes').doc(`${uid}_${id}`));
    const matchRefs = candidateIds.map((id) => db.collection('matches').doc(pairId(uid, id)));
    const blockRefs = candidateIds.flatMap((id) => [
      db.collection('blocks').doc(`${uid}_${id}`),
      db.collection('blocks').doc(`${id}_${uid}`),
    ]);
    const [userSnaps, passSnaps, outgoingLikeSnaps, matchSnaps, blockSnaps] = await Promise.all([
      userRefs.length ? db.getAll(...userRefs) : Promise.resolve([]),
      passRefs.length ? db.getAll(...passRefs) : Promise.resolve([]),
      outgoingLikeRefs.length ? db.getAll(...outgoingLikeRefs) : Promise.resolve([]),
      matchRefs.length ? db.getAll(...matchRefs) : Promise.resolve([]),
      blockRefs.length ? db.getAll(...blockRefs) : Promise.resolve([]),
    ]);
    const active = new Set(userSnaps
      .filter((snap) => isActiveCompliantMember(snap))
      .map((snap) => snap.id));
    const passed = new Set(passSnaps
      .filter((snap) => snap.exists)
      .map((snap) => String(snap.get('toUid') ?? ''))
      .filter((id) => id.length > 0));
    const alreadyLiked = new Set(outgoingLikeSnaps
      .filter((snap) => snap.exists)
      .map((snap) => String(snap.get('toUid') ?? ''))
      .filter((id) => id.length > 0));
    const blocked = blockedPeersFromSnapshots(uid, blockSnaps);
    // A prior match, including an ended match, keeps the pair out of Discover.
    // Reconnecting after an explicit unmatch needs a future consentful flow
    // rather than silently resurfacing the same person.
    const matchedBefore = new Set(matchSnaps
      .filter((snap) => snap.exists)
      .map((snap) => {
        const userAUid = String(snap.get('userAUid') ?? '');
        const userBUid = String(snap.get('userBUid') ?? '');
        return userAUid === uid ? userBUid : userAUid;
      })
      .filter((id) => id.length > 0));

    const output: FirebaseFirestore.DocumentData[] = [];
    for (const doc of profiles.docs) {
      if (
        doc.id === uid
        || !active.has(doc.id)
        || passed.has(doc.id)
        || alreadyLiked.has(doc.id)
        || matchedBefore.has(doc.id)
        || blocked.has(doc.id)
      ) continue;
      if (!candidateMatchesPreferences(requesterProfile, doc.data())) continue;
      output.push(toProfileView(doc.id, doc.data()));
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
    // Charge the caller before any target-specific lookup so invalid/inactive UID
    // probing cannot bypass the request budget.
    await consumeRateLimit(uid, 'like', 120, 60 * 60_000);

    const callerUserRef = db.collection('users').doc(uid);
    const targetUserRef = db.collection('users').doc(toUid);
    const targetProfileRef = db.collection('profiles').doc(toUid);
    const outgoingBlockRef = db.collection('blocks').doc(`${uid}_${toUid}`);
    const incomingBlockRef = db.collection('blocks').doc(`${toUid}_${uid}`);
    const likeRef = db.collection('likes').doc(`${uid}_${toUid}`);
    const reverseRef = db.collection('likes').doc(`${toUid}_${uid}`);
    const matchRef = db.collection('matches').doc(pairId(uid, toUid));
    const passRef = db.collection('profile_passes').doc(`${uid}_${toUid}`);

    const matched = await db.runTransaction(async (tx) => {
      // Every document that can invalidate authorization is read in the same
      // transaction as the Like/Match write. If block/account/profile state
      // changes concurrently, Firestore retries this transaction against the
      // new state instead of committing a stale authorization decision.
      const [
        callerUser,
        targetUser,
        targetProfile,
        outgoingBlock,
        incomingBlock,
        reverse,
        existingMatch,
        existingPass,
      ] = await Promise.all([
        tx.get(callerUserRef),
        tx.get(targetUserRef),
        tx.get(targetProfileRef),
        tx.get(outgoingBlockRef),
        tx.get(incomingBlockRef),
        tx.get(reverseRef),
        tx.get(matchRef),
        tx.get(passRef),
      ]);

      if (!isActiveCompliantMember(callerUser)) {
        throw new HttpsError('permission-denied', 'Complete adult access before connecting.');
      }
      if (!isActiveCompliantMember(targetUser)) {
        throw new HttpsError('permission-denied', 'Interaction unavailable.');
      }
      if (outgoingBlock.exists || incomingBlock.exists) {
        throw new HttpsError('permission-denied', 'Interaction unavailable.');
      }
      assertCanReceiveNewConnection(targetProfile);

      // Once a connection has explicitly ended, do not let direct callable
      // requests silently reactivate it. A future reconnect feature must define
      // new mutual consent and conversation-history behavior first.
      if (existingMatch.exists && existingMatch.get('active') !== true) {
        throw new HttpsError('failed-precondition', 'This previous connection cannot be restarted here.');
      }

      // Reading the pass before deleting it gives concurrent Like/Pass actions
      // deterministic transaction-conflict semantics: the last explicit action
      // that successfully commits wins without leaving both states behind.
      if (existingPass.exists) tx.delete(passRef);
      tx.set(likeRef, {likeId: likeRef.id, fromUid: uid, toUid, createdAt: FieldValue.serverTimestamp()});

      if (existingMatch.exists && existingMatch.get('active') === true) return true;
      if (!reverse.exists) return false;

      const [userAUid, userBUid] = [uid, toUid].sort();
      tx.create(matchRef, {
        matchId: matchRef.id,
        userAUid,
        userBUid,
        createdAt: FieldValue.serverTimestamp(),
        active: true,
      });
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
    // Charge before inspecting a target account so arbitrary UID probing cannot
    // bypass the callable budget.
    await consumeRateLimit(uid, 'conversation', 30, 60 * 60_000);

    const id = pairId(uid, otherUid);
    const callerUserRef = db.collection('users').doc(uid);
    const targetUserRef = db.collection('users').doc(otherUid);
    const outgoingBlockRef = db.collection('blocks').doc(`${uid}_${otherUid}`);
    const incomingBlockRef = db.collection('blocks').doc(`${otherUid}_${uid}`);
    const matchRef = db.collection('matches').doc(id);
    const ref = db.collection('conversations').doc(id);
    const participantUids = [uid, otherUid].sort();

    await db.runTransaction(async (tx) => {
      const [callerUser, targetUser, outgoingBlock, incomingBlock, match, existing] = await Promise.all([
        tx.get(callerUserRef),
        tx.get(targetUserRef),
        tx.get(outgoingBlockRef),
        tx.get(incomingBlockRef),
        tx.get(matchRef),
        tx.get(ref),
      ]);

      if (!isActiveCompliantMember(callerUser)) {
        throw new HttpsError('permission-denied', 'Complete adult access before opening conversations.');
      }
      if (!isActiveCompliantMember(targetUser)) {
        throw new HttpsError('permission-denied', 'Interaction unavailable.');
      }
      if (outgoingBlock.exists || incomingBlock.exists) {
        throw new HttpsError('permission-denied', 'Interaction unavailable.');
      }
      if (!match.exists || match.get('active') !== true) {
        throw new HttpsError('failed-precondition', 'An active match is required.');
      }
      const matchParticipants = [String(match.get('userAUid') ?? ''), String(match.get('userBUid') ?? '')].sort();
      if (matchParticipants[0] !== participantUids[0] || matchParticipants[1] !== participantUids[1]) {
        throw new HttpsError('internal', 'Match integrity check failed.');
      }

      if (!existing.exists) {
        tx.create(ref, {
          conversationId: id,
          participantUids,
          createdAt: FieldValue.serverTimestamp(),
          lastMessageAt: FieldValue.serverTimestamp(),
          active: true,
        });
        return;
      }

      if (existing.get('active') !== true) {
        throw new HttpsError('failed-precondition', 'This conversation is closed.');
      }
      const existingParticipants = existing.get('participantUids');
      if (!Array.isArray(existingParticipants)
        || existingParticipants.length !== 2
        || existingParticipants[0] !== participantUids[0]
        || existingParticipants[1] !== participantUids[1]) {
        throw new HttpsError('internal', 'Conversation integrity check failed.');
      }
      // Opening an existing chat is read-only. In particular, do not reset
      // createdAt or lastMessageAt merely because a participant opened it.
    });
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

    const userRef = db.collection('users').doc(uid);
    let userState = await userRef.get();
    if (!userState.exists) {
      throw new HttpsError('not-found', 'Account record was not found.');
    }
    const deletionPending = userState.get('accountStatus') === 'paused'
      && userState.get('deletionRequestedAt') != null;
    if (!deletionPending && userState.get('accountStatus') !== 'active') {
      throw new HttpsError('permission-denied', 'Account is not available for deletion.');
    }

    // Initial destructive requests are tightly limited. Once deletion has
    // already entered the recoverable paused state, allow enough retries for a
    // transient Storage/Firestore outage without trapping the user for a day.
    await consumeRateLimit(uid, 'delete_account', deletionPending ? 20 : 2, 24 * 60 * 60_000);

    if (!deletionPending) {
      await userRef.set({
        accountStatus: 'paused',
        deletionRequestedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      userState = await userRef.get();
    }
    const originalDeletionRequestedAt = userState.get('deletionRequestedAt');
    if (originalDeletionRequestedAt == null) {
      throw new HttpsError('internal', 'Account deletion could not establish a durable request marker.');
    }

    const minimalPendingAccount = () => ({
      uid,
      accountStatus: 'paused',
      deletionRequestedAt: originalDeletionRequestedAt,
    });

    try {
      const [
        cards, outgoingLikes, incomingLikes, outgoingPasses, incomingPasses,
        matchesA, matchesB, conversations, sentMessages, outgoingBlocks,
        incomingBlocks, privateMedia, grantsOwned, grantsReceived, requestsFrom,
        requestsTo, preferencesAsRecipient, preferencesAsRequester, reportsFrom,
        reportsAgainst, profileMedia,
      ] = await Promise.all([
        db.collection('relationship_cards').where('ownerUid', '==', uid).get(),
        db.collection('likes').where('fromUid', '==', uid).get(),
        db.collection('likes').where('toUid', '==', uid).get(),
        db.collection('profile_passes').where('fromUid', '==', uid).get(),
        db.collection('profile_passes').where('toUid', '==', uid).get(),
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
      deleteDocs(outgoingPasses.docs);
      deleteDocs(incomingPasses.docs);
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
        if (doc.get('active') !== true) continue;
        writer.set(doc.ref, {
          active: false,
          endedAt: FieldValue.serverTimestamp(),
          endedReason: 'account_deleted',
        }, {merge: true});
      }
      for (const doc of conversations.docs) {
        if (doc.get('active') !== true) continue;
        // Connection lifecycle changes must not pretend that a new chat message
        // happened. Preserve the actual lastMessageAt chronology.
        writer.set(doc.ref, {
          active: false,
          endedAt: FieldValue.serverTimestamp(),
          endedReason: 'account_deleted',
        }, {merge: true});
      }
      for (const doc of reportsFrom.docs) writer.set(doc.ref, {reporterUid: '[deleted]'}, {merge: true});
      for (const doc of reportsAgainst.docs) writer.set(doc.ref, {reportedUid: '[deleted]'}, {merge: true});

      writer.delete(db.collection('profiles').doc(uid));
      for (const action of [
        'discover', 'like', 'pass', 'conversation', 'connections_list', 'circle_view', 'delete_account',
        'block', 'unblock', 'block_list', 'unmatch', 'report', 'data_snapshot',
        'moderation_list', 'moderation_review', 'moderation_account',
        'private_media_request', 'private_media_request_response', 'private_media_request_cancel',
        'private_media_preference_clear',
        'private_media_request_list', 'private_media_share_list', 'private_media_inbox_list',
        'private_media_grant', 'private_media_revoke', 'private_media_access',
        'private_media_report', 'private_media_upload', 'private_media_confirm',
        'private_media_review', 'private_media_list',
        'profile_photo_upload', 'profile_photo_confirm', 'profile_photo_review',
        'profile_photo_access', 'profile_photo_delete', 'profile_photo_list', 'profile_photo_moderation_list',
      ]) {
        writer.delete(db.collection('_rate_limits').doc(`${action}_${uid}`));
      }
      await writer.close();

      // Storage cleanup is privacy-critical. Do not swallow failures and then
      // delete Authentication, because that would strand private objects with no
      // user path to retry deletion.
      const bucket = getStorage().bucket();
      await Promise.all([
        bucket.deleteFiles({prefix: `users/${uid}/profile/`}),
        bucket.deleteFiles({prefix: `users/${uid}/profile_quarantine/`}),
        bucket.deleteFiles({prefix: `private_media/${uid}/`}),
        bucket.deleteFiles({prefix: `private_media_quarantine/${uid}/`}),
      ]);

      // Remove email/onboarding/activity fields before the final Auth deletion.
      // If the function is interrupted after this point, only a minimal paused
      // recovery marker remains in Firestore and the user can authenticate again
      // to retry while the Auth identity still exists.
      await userRef.set(minimalPendingAccount());
    } catch (_) {
      try {
        await userRef.set(minimalPendingAccount());
      } catch (_) {
        // Preserve the original failure. A later authenticated retry remains
        // possible as long as the earlier pause write succeeded.
      }
      throw new HttpsError(
        'internal',
        'Account deletion is still pending. Sign in again and retry deletion.',
      );
    }

    try {
      await getAuth().deleteUser(uid);
    } catch (error: any) {
      if (error?.code !== 'auth/user-not-found') {
        throw new HttpsError(
          'internal',
          'Account deletion is still pending. Sign in again and retry deletion.',
        );
      }
    }

    // Auth is gone at this point. A failure to remove this final minimal marker
    // must not resurrect an account or report deletion as failed to a user who
    // can no longer authenticate. The tombstone contains no email/profile data.
    try {
      await userRef.delete();
    } catch (_) {
      console.error('Failed to remove minimal account deletion tombstone after Auth deletion.');
    }
    return {deleted: true};
  },
);

export {blockUser, unblockUser, listMyBlocks, endConnection, submitReport} from './safety';
export {
  listModerationReports,
  reviewModerationReport,
  setAccountModerationState,
} from './moderation';
export {getMyDataSnapshot} from './data_access';
export {passProfile} from './discovery_actions';
export {getCircleForProfile} from './circle_view';
export {
  requestPrivateMedia,
  respondToPrivateMediaRequest,
  clearPrivateMediaRequestPreference,
  grantPrivateMedia,
  revokePrivateMedia,
  getPrivateMediaAccess,
  reportPrivateMedia,
} from './private_vault';
export {cancelPrivateMediaRequest} from './private_vault_consent';
export {
  listMyPrivateMediaRequests,
  listMyPrivateMediaShares,
  listMyPrivateMediaInbox,
} from './private_vault_listing';
export {
  beginPrivateMediaUpload,
  confirmPrivateMediaUpload,
  processPrivateMedia,
  reviewPrivateMedia,
  listMyPrivateMedia,
} from './private_vault_upload';
export {
  beginProfilePhotoUpload,
  confirmProfilePhotoUpload,
  processProfilePhoto,
  reviewProfilePhoto,
  getProfilePhotoAccess,
  deleteProfilePhoto,
} from './profile_media';
export {listProfilePhotosForReview} from './profile_media_moderation';
export {listMyProfilePhotos} from './profile_media_listing';
export {listMyConnections} from './profile_view';


export {
  createCircle,
  inviteCircleMember,
  respondToCircleInvite,
  leaveCircle,
  listMyCircles,
} from './circle_membership';
