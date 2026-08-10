import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

const queueStatuses = new Set(['open', 'reviewing', 'escalated']);
const reviewStatuses = new Set(['reviewing', 'escalated', 'resolved', 'dismissed']);

function requireModerator(auth: {uid: string; token?: Record<string, unknown>} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  if (auth.token?.moderator !== true && auth.token?.admin !== true) {
    throw new HttpsError('permission-denied', 'Moderator access required.');
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

function timestampMillis(value: unknown): number | null {
  const candidate = value as {toMillis?: () => number} | null | undefined;
  return candidate?.toMillis?.() ?? null;
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

export const listModerationReports = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    const moderatorUid = requireModerator(request.auth);
    await consumeModeratorRateLimit(moderatorUid, 'moderation_list', 120, 60_000);

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
      const noteRaw = internal?.exists ? internal.get('note') : null;
      return {
        reportId: doc.id,
        reporterUid: String(doc.get('reporterUid') ?? ''),
        reportedUid: String(doc.get('reportedUid') ?? ''),
        reason: typeof reasonRaw === 'string' ? reasonRaw.slice(0, 80) : 'other',
        details: typeof detailsRaw === 'string' ? detailsRaw.slice(0, 2000) : '',
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
    await consumeModeratorRateLimit(moderatorUid, 'moderation_review', 120, 60_000);

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
