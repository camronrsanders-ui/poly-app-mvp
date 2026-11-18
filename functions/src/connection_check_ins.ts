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
  normalizeCheckInStateInput,
  normalizeSharedCheckInNoteInput,
  projectCheckIn,
} from './connection_check_in_fields';
import {
  CheckInWriteStore,
  CheckInWriteTransaction,
  commitCheckInStateWrite,
  commitClearCheckInState,
  commitSharedCheckInNoteWrite,
  commitClearSharedCheckInNote,
} from './connection_check_in_writes';

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

// Production binding for the transactional write orchestration in
// connection_check_in_writes.ts. Every document access a write makes
// goes through the transaction (tx.get / tx.set): the read that feeds
// the pure computation is the snapshot the commit is checked against,
// so a concurrent partner write forces a retry-and-recompute instead
// of being silently overwritten. The payload shape is exactly what
// the pre-transaction handlers wrote by hand — same fields, same
// merge semantics, createdAt only on the first write.
function firestoreCheckInWriteStore(
  db: FirebaseFirestore.Firestore,
  participantUids: string[],
): CheckInWriteStore {
  return {
    runTransaction: (updateFunction) =>
      db.runTransaction(async (tx) => {
        const boundTx: CheckInWriteTransaction = {
          get: async (conversationId) => {
            const snap = await tx.get(
              db.collection('connection_check_ins').doc(conversationId),
            );
            return docDataFromFirestore(snap, participantUids);
          },
          set: (conversationId, write) => {
            const payload: Record<string, unknown> = {
              updatedAt: FieldValue.serverTimestamp(),
            };
            if (write.scaffold) {
              payload.conversationId = conversationId;
              payload.participantUids = participantUids;
            }
            if (write.stampCreatedAt) {
              payload.createdAt = FieldValue.serverTimestamp();
            }
            if (write.states) {
              payload.states = statesForFirestore(write.states);
            }
            if (write.sharedNote) {
              payload.sharedNote = {
                text: write.sharedNote.text,
                updatedByUid: write.sharedNote.updatedByUid,
                updatedAt: Timestamp.fromMillis(write.sharedNote.updatedAtMs),
              };
            }
            if (write.deleteSharedNote) {
              payload.sharedNote = FieldValue.delete();
            }
            tx.set(
              db.collection('connection_check_ins').doc(conversationId),
              payload,
              {merge: true},
            );
          },
        };
        return updateFunction(boundTx);
      }),
  };
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

    await commitCheckInStateWrite(
      firestoreCheckInWriteStore(db, participantUids),
      conversationId,
      participantUids,
      uid,
      input,
      Date.now(),
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
    await commitClearCheckInState(
      firestoreCheckInWriteStore(db, participantUids),
      conversationId,
      participantUids,
      uid,
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

    await commitSharedCheckInNoteWrite(
      firestoreCheckInWriteStore(db, participantUids),
      conversationId,
      participantUids,
      uid,
      input.text,
      Date.now(),
    );
    return {updated: true};
  },
);

export const clearSharedCheckInNote = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    requireWritesEnabled();
    const {db, conversationId, participantUids} = await guardConversation(
      request,
      'check_in_note_clear',
      60,
    );
    await commitClearSharedCheckInNote(
      firestoreCheckInWriteStore(db, participantUids),
      conversationId,
    );
    return {cleared: true};
  },
);
