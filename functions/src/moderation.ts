import {getAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

const queueStatuses = new Set(['open', 'reviewing', 'escalated']);
const reviewStatuses = new Set(['reviewing', 'escalated', 'resolved', 'dismissed']);
const accountStates = new Set(['active', 'suspended', 'banned']);
const accountReasonCodes = new Set([
  'reported_abuse',
  'security_risk',
  'spam_fraud',
  'policy_violation',
  'appeal_granted',
  'other',
]);

type TrustedAuth = {uid: string; token?: Record<string, unknown>} | undefined;

function requireModerator(auth: TrustedAuth): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  if (auth.token?.moderator !== true && auth.token?.admin !== true && auth.token?.superadmin !== true) {
    throw new HttpsError('permission-denied', 'Moderator access required.');
  }
  return auth.uid;
}

function requireAdmin(auth: TrustedAuth): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  if (auth.token?.admin !== true && auth.token?.superadmin !== true) {
    throw new HttpsError('permission-denied', 'Administrator access required.');
  }
  return auth.uid;
}

function requireReportId(raw: unknown): string {
  const value = String(raw ?? '').trim();
  if (!value || value.length > 128 || !/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new HttpsError('invalid-argument', 'Invalid report ID.');
  }
  return value;
}

function requireTargetUid(raw: unknown, callerUid: string): string {
  const value = String(raw ?? '').trim();
  if (!value || value === callerUid || value.length > 128 || !/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new HttpsError('invalid-argument', 'Invalid target account.');
  }
  return value;
}

function timestampMillis(value: unknown): number | null {
  const candidate = value as {toMillis?: () => number} | null | undefined;
  return candidate?.toMillis?.() ?? null;
}

async function assertActiveStaff(uid: string): Promise<void> {
  const user = await getFirestore().collection('users').doc(uid).get();
  if (!user.exists || user.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Staff account is not active.');
  }
}

async function consumeModeratorRateLimit(
  uid: string,
  action: string,
  max: number,
  windowMs: number,
): Promise<void> {
  const db = getFirestore();
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
      throw new HttpsError('resource-exhausted', 'Too many moderation requests. Try again later.');
    }
    tx.set(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

async function terminateForBan(targetUid: string): Promise<void> {
  const db = getFirestore();
  const [
    outgoingLikes,
    incomingLikes,
    matchesA,
    matchesB,
    conversations,
    grantsOwned,
    grantsReceived,
    requestsFrom,
    requestsTo,
  ] = await Promise.all([
    db.collection('likes').where('fromUid', '==', targetUid).get(),
    db.collection('likes').where('toUid', '==', targetUid).get(),
    db.collection('matches').where('userAUid', '==', targetUid).get(),
    db.collection('matches').where('userBUid', '==', targetUid).get(),
    db.collection('conversations').where('participantUids', 'array-contains', targetUid).get(),
    db.collection('private_media_grants').where('ownerUid', '==', targetUid).get(),
    db.collection('private_media_grants').where('recipientUid', '==', targetUid).get(),
    db.collection('private_media_requests').where('requesterUid', '==', targetUid).get(),
    db.collection('private_media_requests').where('recipientUid', '==', targetUid).get(),
  ]);

  const writer = db.bulkWriter();
  const seen = new Set<string>();
  for (const doc of [...outgoingLikes.docs, ...incomingLikes.docs]) {
    if (seen.has(doc.ref.path)) continue;
    seen.add(doc.ref.path);
    writer.delete(doc.ref);
  }
  for (const doc of [...matchesA.docs, ...matchesB.docs]) {
    if (doc.get('active') !== true) continue;
    writer.set(doc.ref, {
      active: false,
      endedAt: FieldValue.serverTimestamp(),
      endedReason: 'moderation_ban',
    }, {merge: true});
  }
  for (const doc of conversations.docs) {
    if (doc.get('active') !== true) continue;
    writer.set(doc.ref, {
      active: false,
      endedAt: FieldValue.serverTimestamp(),
      endedReason: 'moderation_ban',
    }, {merge: true});
  }
  for (const doc of [...grantsOwned.docs, ...grantsReceived.docs]) {
    writer.set(doc.ref, {
      active: false,
      revokedAt: FieldValue.serverTimestamp(),
      revokedReason: 'moderation_ban',
    }, {merge: true});
  }
  for (const doc of [...requestsFrom.docs, ...requestsTo.docs]) {
    writer.set(doc.ref, {
      status: 'cancelled',
      cancelledAt: FieldValue.serverTimestamp(),
      cancelledReason: 'moderation_ban',
    }, {merge: true});
  }
  await writer.close();
}

export const listModerationReports = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    const moderatorUid = requireModerator(request.auth);
    await Promise.all([
      assertActiveStaff(moderatorUid),
      consumeModeratorRateLimit(moderatorUid, 'moderation_list', 120, 60_000),
    ]);

    const status = String(request.data?.status ?? 'open').trim();
    if (!queueStatuses.has(status)) {
      throw new HttpsError('invalid-argument', 'Unsupported moderation queue status.');
    }
    const requestedLimit = Number(request.data?.limit ?? 50);
    const limit = Number.isFinite(requestedLimit)
      ? Math.min(Math.max(Math.trunc(requestedLimit), 1), 100)
      : 50;

    const db = getFirestore();
    const snapshot = await db.collection('reports')
      .where('status', '==', status)
      .limit(limit)
      .get();
    if (snapshot.empty) return {reports: []};

    const moderationRefs = snapshot.docs.map((doc) => db.collection('report_moderation').doc(doc.id));
    const moderationSnaps = await db.getAll(...moderationRefs);
    const moderationById = new Map(moderationSnaps.map((snap) => [snap.id, snap]));

    const reports = snapshot.docs.map((doc) => {
      const internal = moderationById.get(doc.id);
      const detailsRaw = doc.get('details');
      const reasonRaw = doc.get('reason');
      const contentTypeRaw = doc.get('contentType');
      const contentIdRaw = doc.get('contentId');
      const conversationIdRaw = doc.get('conversationId');
      const noteRaw = internal?.exists ? internal.get('note') : null;
      return {
        reportId: doc.id,
        reporterUid: String(doc.get('reporterUid') ?? ''),
        reportedUid: String(doc.get('reportedUid') ?? ''),
        reason: typeof reasonRaw === 'string' ? reasonRaw.slice(0, 80) : 'other',
        details: typeof detailsRaw === 'string' ? detailsRaw.slice(0, 2000) : '',
        contentType: typeof contentTypeRaw === 'string' ? contentTypeRaw.slice(0, 32) : 'account',
        contentId: typeof contentIdRaw === 'string' ? contentIdRaw.slice(0, 128) : null,
        conversationId: typeof conversationIdRaw === 'string' ? conversationIdRaw.slice(0, 128) : null,
        status: String(doc.get('status') ?? 'open'),
        createdAtMs: timestampMillis(doc.get('createdAt')),
        reviewedAtMs: timestampMillis(doc.get('reviewedAt')),
        internalNote: typeof noteRaw === 'string' ? noteRaw.slice(0, 1000) : '',
      };
    });
    reports.sort((a, b) => (b.createdAtMs ?? 0) - (a.createdAtMs ?? 0));
    return {reports};
  },
);

export const reviewModerationReport = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    const moderatorUid = requireModerator(request.auth);
    await Promise.all([
      assertActiveStaff(moderatorUid),
      consumeModeratorRateLimit(moderatorUid, 'moderation_review', 120, 60_000),
    ]);

    const reportId = requireReportId(request.data?.reportId);
    const status = String(request.data?.status ?? '').trim();
    const note = String(request.data?.note ?? '').trim();
    if (!reviewStatuses.has(status)) {
      throw new HttpsError('invalid-argument', 'Unsupported moderation status.');
    }
    if (note.length > 1000) {
      throw new HttpsError('invalid-argument', 'Moderation note is too long.');
    }

    const db = getFirestore();
    const reportRef = db.collection('reports').doc(reportId);
    const internalRef = db.collection('report_moderation').doc(reportId);
    await db.runTransaction(async (tx) => {
      const report = await tx.get(reportRef);
      if (!report.exists) throw new HttpsError('not-found', 'Report not found.');

      tx.set(reportRef, {
        status,
        reviewedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      tx.set(internalRef, {
        reportId,
        moderatorUid,
        status,
        note,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });

    return {reportId, status};
  },
);

export const setAccountModerationState = onCall(
  {enforceAppCheck: true, maxInstances: 5},
  async (request) => {
    const adminUid = requireAdmin(request.auth);
    await Promise.all([
      assertActiveStaff(adminUid),
      consumeModeratorRateLimit(adminUid, 'moderation_account', 60, 60 * 60_000),
    ]);

    const targetUid = requireTargetUid(request.data?.targetUid, adminUid);
    const state = String(request.data?.state ?? '').trim();
    const reasonCode = String(request.data?.reasonCode ?? '').trim();
    const note = String(request.data?.note ?? '').trim();
    if (!accountStates.has(state)) {
      throw new HttpsError('invalid-argument', 'Unsupported account state.');
    }
    if (!accountReasonCodes.has(reasonCode)) {
      throw new HttpsError('invalid-argument', 'Unsupported moderation reason.');
    }
    if (note.length > 1000) {
      throw new HttpsError('invalid-argument', 'Moderation note is too long.');
    }

    const db = getFirestore();
    const userRef = db.collection('users').doc(targetUid);
    const [user, targetAuth] = await Promise.all([
      userRef.get(),
      getAuth().getUser(targetUid).catch((error: any) => {
        if (error?.code === 'auth/user-not-found') return null;
        throw error;
      }),
    ]);
    if (!user.exists || targetAuth == null) {
      throw new HttpsError('not-found', 'Target account not found.');
    }
    if (user.get('accountStatus') === 'paused' && user.get('deletionRequestedAt') != null) {
      throw new HttpsError('failed-precondition', 'An account pending deletion cannot be moderated into another state.');
    }

    const targetClaims = targetAuth.customClaims ?? {};
    const targetPrivileged = targetClaims.moderator === true
      || targetClaims.admin === true
      || targetClaims.superadmin === true;
    if (targetPrivileged && request.auth?.token?.superadmin !== true) {
      throw new HttpsError('permission-denied', 'Super-administrator access is required for a privileged target.');
    }

    // Fail closed across the Auth + Firestore boundary. Restrictive states are
    // written to Firestore first. Reinstatement enables Auth first while the old
    // restrictive Firestore state still blocks app access until the second step
    // succeeds.
    if (state === 'active') {
      await getAuth().updateUser(targetUid, {disabled: false});
      await userRef.set({accountStatus: 'active'}, {merge: true});
    } else {
      await userRef.set({accountStatus: state}, {merge: true});
      await getAuth().updateUser(targetUid, {disabled: state === 'banned'});
    }

    if (state === 'banned') {
      await terminateForBan(targetUid);
    }

    await Promise.all([
      db.collection('account_moderation').doc(targetUid).set({
        targetUid,
        state,
        reasonCode,
        note,
        updatedByUid: adminUid,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true}),
      db.collection('moderation_audit').add({
        action: 'account_state_changed',
        targetUid,
        state,
        reasonCode,
        actorUid: adminUid,
        createdAt: FieldValue.serverTimestamp(),
      }),
    ]);

    return {targetUid, state};
  },
);