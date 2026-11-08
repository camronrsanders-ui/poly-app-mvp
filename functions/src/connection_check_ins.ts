import {
  FieldValue,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {assertActiveCompliantMember} from './account_compliance';
import {
  CheckInDocData,
  CheckInSlotData,
  SharedCheckInNoteData,
  applyCheckInStateWrite,
  applyClearCheckInState,
  applySharedCheckInNoteWrite,
  normalizeCheckInStateInput,
  normalizeSharedCheckInNoteInput,
  projectCheckIn,
} from './connection_check_in_fields';

// Check-ins are enabled in the lab build so the feature is exercisable
// end to end. Flipping this to false freezes every check-in write path
// (reads stay available). Production gating is a port-time decision; the
// client mirror is FeatureFlags.checkInEnabled.
const CONNECTION_CHECK_INS_ENABLED = true;

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

async function conversationForMember(
  db: FirebaseFirestore.Firestore,
  conversationId: string,
  uid: string,
  requireActive: boolean,
): Promise<FirebaseFirestore.DocumentSnapshot> {
  const conversation = await db.collection('conversations').doc(conversationId).get();
  if (!conversation.exists) {
    throw new HttpsError('not-found', 'Conversation not found.');
  }
  const participantUids = conversation.get('participantUids');
  if (!Array.isArray(participantUids)
      || participantUids.length !== 2
      || !participantUids.includes(uid)) {
    throw new HttpsError(
      'permission-denied',
      'Check-ins are available only to conversation participants.',
    );
  }
  if (requireActive && conversation.get('active') !== true) {
    throw new HttpsError('failed-precondition', 'This conversation is no longer active.');
  }

  if (requireActive) {
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

  return conversation;
}

function slotFromFirestore(raw: unknown): CheckInSlotData | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const data = raw as Record<string, unknown>;
  const updatedAtMs = timestampMillis(data.updatedAt);
  const expiresAtMs = timestampMillis(data.expiresAt);
  const state = String(data.state ?? '').trim();
  if (!state || updatedAtMs === null || expiresAtMs === null) return null;
  return {
    state: state as CheckInSlotData['state'],
    note: String(data.note ?? ''),
    updatedAtMs,
    expiresAtMs,
  };
}

function docDataFromFirestore(
  snap: FirebaseFirestore.DocumentSnapshot,
  participantUids: string[],
): CheckInDocData | null {
  if (!snap.exists) return null;
  const rawStates = snap.get('states');
  const states: Record<string, CheckInSlotData> = {};
  if (rawStates && typeof rawStates === 'object' && !Array.isArray(rawStates)) {
    for (const [slotUid, rawSlot] of Object.entries(
      rawStates as Record<string, unknown>,
    )) {
      const slot = slotFromFirestore(rawSlot);
      if (slot) states[slotUid] = slot;
    }
  }
  const rawNote = snap.get('sharedNote');
  let sharedNote: SharedCheckInNoteData | null = null;
  if (rawNote && typeof rawNote === 'object' && !Array.isArray(rawNote)) {
    const noteData = rawNote as Record<string, unknown>;
    const updatedAtMs = timestampMillis(noteData.updatedAt);
    if (updatedAtMs !== null) {
      sharedNote = {
        text: String(noteData.text ?? ''),
        updatedByUid: String(noteData.updatedByUid ?? ''),
        updatedAtMs,
      };
    }
  }
  return {participantUids, states, sharedNote};
}

function slotForFirestore(slot: CheckInSlotData): Record<string, unknown> {
  return {
    state: slot.state,
    note: slot.note,
    updatedAt: Timestamp.fromMillis(slot.updatedAtMs),
    expiresAt: Timestamp.fromMillis(slot.expiresAtMs),
  };
}

function statesForFirestore(
  states: Record<string, CheckInSlotData>,
): Record<string, unknown> {
  const converted: Record<string, unknown> = {};
  for (const [slotUid, slot] of Object.entries(states)) {
    converted[slotUid] = slotForFirestore(slot);
  }
  return converted;
}

function requireWritesEnabled(): void {
  if (!CONNECTION_CHECK_INS_ENABLED) {
    throw new HttpsError(
      'failed-precondition',
      'Check-ins are not enabled in this build.',
    );
  }
}

interface GuardedConversation {
  db: FirebaseFirestore.Firestore;
  participantUids: string[];
}

async function guardConversation(
  request: {auth?: {uid: string}; data?: Record<string, unknown>},
  rateAction: string,
  rateMax: number,
): Promise<GuardedConversation & {uid: string; conversationId: string}> {
  const uid = requireUid(request.auth);
  const db = getFirestore();
  const conversationId = requireReference(
    request.data?.conversationId,
    'conversation reference',
  );
  await Promise.all([
    assertActiveCompliantMember(db, uid),
    enforceRateLimit(uid, rateAction, rateMax, 60 * 60_000),
  ]);
  const conversation = await conversationForMember(db, conversationId, uid, true);
  const participantUids = (conversation.get('participantUids') as unknown[])
    .map((participantUid) => String(participantUid));
  return {db, uid, conversationId, participantUids};
}

export const getCheckIn = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const {db, uid, conversationId, participantUids} = await guardConversation(
      request,
      'check_in_get',
      120,
    );
    const snap = await db
      .collection('connection_check_ins')
      .doc(conversationId)
      .get();
    const projected = projectCheckIn(
      docDataFromFirestore(snap, participantUids),
      uid,
      Date.now(),
    );
    return {conversationId, ...projected};
  },
);

export const setMyCheckInState = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    requireWritesEnabled();
    const {db, uid, conversationId, participantUids} = await guardConversation(
      request,
      'check_in_state_set',
      60,
    );

    let input;
    try {
      input = normalizeCheckInStateInput(request.data);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Invalid check-in.';
      throw new HttpsError('invalid-argument', message);
    }

    const ref = db.collection('connection_check_ins').doc(conversationId);
    const snap = await ref.get();
    const nowMs = Date.now();
    const states = applyCheckInStateWrite(
      docDataFromFirestore(snap, participantUids),
      participantUids,
      uid,
      input,
      nowMs,
    );
    await ref.set(
      {
        conversationId,
        participantUids,
        states: statesForFirestore(states),
        updatedAt: FieldValue.serverTimestamp(),
        ...(snap.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      },
      {merge: true},
    );
    return {updated: true};
  },
);

export const clearMyCheckInState = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    requireWritesEnabled();
    const {db, uid, conversationId, participantUids} = await guardConversation(
      request,
      'check_in_state_clear',
      60,
    );
    const ref = db.collection('connection_check_ins').doc(conversationId);
    const snap = await ref.get();
    if (!snap.exists) return {cleared: true};
    const states = applyClearCheckInState(
      docDataFromFirestore(snap, participantUids),
      participantUids,
      uid,
    );
    await ref.set(
      {
        states: statesForFirestore(states),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    return {cleared: true};
  },
);

export const setSharedCheckInNote = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    requireWritesEnabled();
    const {db, uid, conversationId, participantUids} = await guardConversation(
      request,
      'check_in_note_set',
      60,
    );

    let input;
    try {
      input = normalizeSharedCheckInNoteInput(request.data);
    } catch (error) {
      const message = error instanceof Error
        ? error.message
        : 'Invalid shared note.';
      throw new HttpsError('invalid-argument', message);
    }

    const sharedNote = applySharedCheckInNoteWrite(
      participantUids,
      uid,
      input.text,
      Date.now(),
    );
    const ref = db.collection('connection_check_ins').doc(conversationId);
    const snap = await ref.get();
    await ref.set(
      {
        conversationId,
        participantUids,
        sharedNote: {
          text: sharedNote.text,
          updatedByUid: sharedNote.updatedByUid,
          updatedAt: Timestamp.fromMillis(sharedNote.updatedAtMs),
        },
        updatedAt: FieldValue.serverTimestamp(),
        ...(snap.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      },
      {merge: true},
    );
    return {updated: true};
  },
);

export const clearSharedCheckInNote = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    requireWritesEnabled();
    const {db, conversationId} = await guardConversation(
      request,
      'check_in_note_clear',
      60,
    );
    const ref = db.collection('connection_check_ins').doc(conversationId);
    const snap = await ref.get();
    if (!snap.exists) return {cleared: true};
    await ref.set(
      {
        sharedNote: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    return {cleared: true};
  },
);
