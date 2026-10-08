import {FieldValue, Timestamp, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {assertActiveCompliantMember} from './account_compliance';
import {normalizeSharedPlanInput, SharedPlanInput} from './shared_plan_fields';

// Plans are modeled and testable now, but creation stays fail-closed until the
// structured-card UI has its own approval and end-to-end staging validation.
const SHARED_PLANS_CREATE_ENABLED = false;
const DISPLAYABLE_SHARED_PLAN_STATUSES = new Set(['active', 'cancelled']);

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

function requireReference(raw: unknown, label: string): string {
  const value = String(raw ?? '').trim();
  if (!value || value.length > 128 || !/^[A-Za-z0-9:_-]+$/.test(value)) {
    throw new HttpsError('invalid-argument', `Invalid ${label}.`);
  }
  return value;
}

function timestampMillis(value: unknown): number | null {
  const candidate = value as {toMillis?: () => number} | null | undefined;
  return candidate?.toMillis?.() ?? null;
}

function isDisplayableSharedPlan(
  doc: FirebaseFirestore.QueryDocumentSnapshot,
): boolean {
  const status = String(doc.get('planStatus') ?? '').trim();
  const title = String(doc.get('planTitle') ?? '').trim();
  const creatorUid = String(doc.get('senderUid') ?? '').trim();
  return DISPLAYABLE_SHARED_PLAN_STATUSES.has(status)
    && title.length > 0
    && title.length <= 120
    && creatorUid.length > 0
    && creatorUid.length <= 128
    && doc.get('plannedFor') instanceof Timestamp;
}

async function enforceRateLimit(
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
    const start = snap.get('windowStart')?.toMillis?.() ?? 0;
    const count = Number(snap.get('count') ?? 0);
    if (!snap.exists || now - start >= windowMs) {
      tx.set(ref, {
        uid,
        action,
        count: 1,
        windowStart: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }
    if (count >= max) {
      throw new HttpsError('resource-exhausted', 'Please wait a moment and try again.');
    }
    tx.update(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()});
  });
}

async function assertActiveConversationParticipant(
  db: FirebaseFirestore.Firestore,
  conversationId: string,
  uid: string,
): Promise<void> {
  const conversation = await db.collection('conversations').doc(conversationId).get();
  if (!conversation.exists || conversation.get('active') !== true) {
    throw new HttpsError('failed-precondition', 'This conversation is no longer active.');
  }
  const participantUids = conversation.get('participantUids');
  if (!Array.isArray(participantUids)
      || participantUids.length !== 2
      || !participantUids.includes(uid)) {
    throw new HttpsError(
      'permission-denied',
      'Plans are available only to conversation participants.',
    );
  }

  await Promise.all(
    participantUids.map((participantUid) =>
      assertActiveCompliantMember(db, String(participantUid))),
  );
  const [forward, reverse] = await db.getAll(
    db.collection('blocks').doc(`${participantUids[0]}_${participantUids[1]}`),
    db.collection('blocks').doc(`${participantUids[1]}_${participantUids[0]}`),
  );
  if (forward.exists || reverse.exists) {
    throw new HttpsError('permission-denied', 'This conversation is unavailable.');
  }
}

function normalizedPlanOrThrow(raw: unknown): SharedPlanInput {
  try {
    return normalizeSharedPlanInput(raw);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Invalid shared plan.';
    throw new HttpsError('invalid-argument', message);
  }
}

function planResult(doc: FirebaseFirestore.QueryDocumentSnapshot): Record<string, unknown> {
  return {
    planId: doc.id,
    creatorUid: String(doc.get('senderUid') ?? ''),
    title: String(doc.get('planTitle') ?? ''),
    note: String(doc.get('planNote') ?? ''),
    placeLabel: String(doc.get('placeLabel') ?? ''),
    plannedForMs: timestampMillis(doc.get('plannedFor')),
    status: String(doc.get('planStatus') ?? ''),
    createdAtMs: timestampMillis(doc.get('createdAt')),
    updatedAtMs: timestampMillis(doc.get('updatedAt')),
    cancelledAtMs: timestampMillis(doc.get('cancelledAt')),
  };
}

export const createSharedPlan = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const uid = requireUid(request.auth);
    if (!SHARED_PLANS_CREATE_ENABLED) {
      throw new HttpsError(
        'failed-precondition',
        'Plans are not enabled in this build.',
      );
    }

    const db = getFirestore();
    const conversationId = requireReference(
      request.data?.conversationId,
      'conversation reference',
    );
    await Promise.all([
      assertActiveCompliantMember(db, uid),
      enforceRateLimit(uid, 'shared_plan_create', 20, 60 * 60_000),
    ]);
    await assertActiveConversationParticipant(db, conversationId, uid);
    const input = normalizedPlanOrThrow(request.data);

    const ref = db.collection('messages').doc();
    await ref.set({
      conversationId,
      senderUid: uid,
      text: input.title,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      isDeleted: false,
      messageType: 'shared_plan',
      readBy: [uid],
      planTitle: input.title,
      planNote: input.note,
      placeLabel: input.placeLabel,
      plannedFor: Timestamp.fromMillis(input.plannedForMs),
      planStatus: 'active',
    });
    return {planId: ref.id};
  },
);

export const listSharedPlans = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const db = getFirestore();
    const uid = requireUid(request.auth);
    const conversationId = requireReference(
      request.data?.conversationId,
      'conversation reference',
    );
    await Promise.all([
      assertActiveCompliantMember(db, uid),
      enforceRateLimit(uid, 'shared_plan_list', 120, 60 * 60_000),
    ]);
    await assertActiveConversationParticipant(db, conversationId, uid);

    const snapshot = await db.collection('messages')
      .where('conversationId', '==', conversationId)
      .where('messageType', '==', 'shared_plan')
      .orderBy('plannedFor', 'asc')
      .limit(100)
      .get();
    return {
      plans: snapshot.docs.filter(isDisplayableSharedPlan).map(planResult),
    };
  },
);

export const updateSharedPlan = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const db = getFirestore();
    const uid = requireUid(request.auth);
    const conversationId = requireReference(
      request.data?.conversationId,
      'conversation reference',
    );
    const planId = requireReference(request.data?.planId, 'plan reference');
    await Promise.all([
      assertActiveCompliantMember(db, uid),
      enforceRateLimit(uid, 'shared_plan_update', 40, 60 * 60_000),
    ]);
    await assertActiveConversationParticipant(db, conversationId, uid);
    const input = normalizedPlanOrThrow(request.data);

    const ref = db.collection('messages').doc(planId);
    await db.runTransaction(async (tx) => {
      const plan = await tx.get(ref);
      if (!plan.exists
          || plan.get('messageType') !== 'shared_plan'
          || plan.get('conversationId') !== conversationId
          || plan.get('senderUid') !== uid) {
        throw new HttpsError('not-found', 'Plan not found.');
      }
      if (plan.get('planStatus') !== 'active') {
        throw new HttpsError('failed-precondition', 'Only active plans can be edited.');
      }
      tx.update(ref, {
        text: input.title,
        planTitle: input.title,
        planNote: input.note,
        placeLabel: input.placeLabel,
        plannedFor: Timestamp.fromMillis(input.plannedForMs),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return {updated: true};
  },
);

export const cancelSharedPlan = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const db = getFirestore();
    const uid = requireUid(request.auth);
    const conversationId = requireReference(
      request.data?.conversationId,
      'conversation reference',
    );
    const planId = requireReference(request.data?.planId, 'plan reference');
    await Promise.all([
      assertActiveCompliantMember(db, uid),
      enforceRateLimit(uid, 'shared_plan_cancel', 40, 60 * 60_000),
    ]);
    await assertActiveConversationParticipant(db, conversationId, uid);

    const ref = db.collection('messages').doc(planId);
    await db.runTransaction(async (tx) => {
      const plan = await tx.get(ref);
      if (!plan.exists
          || plan.get('messageType') !== 'shared_plan'
          || plan.get('conversationId') !== conversationId
          || plan.get('senderUid') !== uid) {
        throw new HttpsError('not-found', 'Plan not found.');
      }
      const status = plan.get('planStatus');
      if (status === 'cancelled') return;
      if (status !== 'active') {
        throw new HttpsError(
          'failed-precondition',
          'Only active plans can be cancelled.',
        );
      }
      tx.update(ref, {
        planStatus: 'cancelled',
        cancelledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return {cancelled: true};
  },
);
