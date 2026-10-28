// Bilateral check-in vocabulary, validation, and pure document logic.
//
// The callables in connection_check_ins.ts own all Firestore access; this
// module owns the rules that must stay testable without a database: the
// state vocabulary, text limits, the 24-hour expiry, own-slot-only writes,
// and shared-note attribution. Timestamps travel as epoch millis here; the
// callable layer converts to/from Firestore Timestamps at the boundary.

export type CheckInStateId =
  | 'doing_well'
  | 'okay'
  | 'tender'
  | 'need_space'
  | 'want_to_talk'
  | 'celebrating';

export interface CheckInStateOption {
  id: CheckInStateId;
  label: string;
}

// Plain-language states, per the Phase 2 spec §3.1: the Stitch register
// ("Holding Space & Grounded", "Radiating & Joyful") translated into the
// app's plain register. The exact list is a copy decision for the founder;
// changing it changes both this module and the client mirror.
export const CHECK_IN_STATES: readonly CheckInStateOption[] = [
  {id: 'doing_well', label: 'Doing well'},
  {id: 'okay', label: 'Okay'},
  {id: 'tender', label: 'Tender / having a hard day'},
  {id: 'need_space', label: 'Need space'},
  {id: 'want_to_talk', label: 'Want to talk'},
  {id: 'celebrating', label: 'Celebrating something'},
];

const CHECK_IN_STATE_IDS: ReadonlySet<string> = new Set(
  CHECK_IN_STATES.map((option) => option.id),
);

// A check-in state is a present-tense signal ("how are we doing right
// now?"), so it expires 24 hours after it was posted. Expiry is enforced
// at read time in projectCheckIn: an expired slot is returned as absent,
// never as a stale state pinned to a person.
export const CHECK_IN_STATE_TTL_MS = 24 * 60 * 60_000;

export const CHECK_IN_NOTE_MAX_LENGTH = 280;
export const CHECK_IN_SHARED_NOTE_MAX_LENGTH = 280;

export interface CheckInSlotData {
  state: CheckInStateId;
  note: string;
  updatedAtMs: number;
  expiresAtMs: number;
}

export interface SharedCheckInNoteData {
  text: string;
  updatedByUid: string;
  updatedAtMs: number;
}

export interface CheckInDocData {
  participantUids: string[];
  states: Record<string, CheckInSlotData>;
  sharedNote: SharedCheckInNoteData | null;
}

export interface CheckInStateInput {
  state: CheckInStateId;
  note: string;
}

export interface ProjectedCheckIn {
  otherUid: string;
  myState: CheckInSlotData | null;
  otherState: CheckInSlotData | null;
  sharedNote: SharedCheckInNoteData | null;
}

const severePatterns = [
  /(i will|i am going to)\s+(kill|rape|hurt)\s+(you|u)/i,
  /kill\s+yourself/i,
  /(looking\s+for|seeking|want\s+to\s+meet|dm\s+me\s+if).{0,32}(minor|underage|child|kid)/i,
  /(sex|nudes?|naked|porn|explicit).{0,24}(with|from|of).{0,24}(minor|underage|child|kid)/i,
  /(minor|underage|child|kid).{0,24}(sex|nudes?|naked|porn|explicit)/i,
];

function text(
  value: unknown,
  label: string,
  maxLength: number,
  required = false,
): string {
  const normalized = String(value ?? '').trim();
  if ((required && !normalized) || normalized.length > maxLength) {
    throw new Error(`Invalid ${label}.`);
  }
  if (normalized && severePatterns.some((pattern) => pattern.test(normalized))) {
    throw new Error(`${label} contains prohibited content.`);
  }
  return normalized;
}

function assertParticipant(participantUids: string[], uid: string): void {
  if (!participantUids.includes(uid)) {
    throw new Error(
      'Check-ins are available only to conversation participants.',
    );
  }
}

export function emptyCheckInDoc(participantUids: string[]): CheckInDocData {
  return {
    participantUids: [...participantUids],
    states: {},
    sharedNote: null,
  };
}

export function normalizeCheckInStateInput(raw: unknown): CheckInStateInput {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new Error('Invalid check-in.');
  }
  const data = raw as Record<string, unknown>;
  const state = String(data.state ?? '').trim();
  if (!CHECK_IN_STATE_IDS.has(state)) {
    throw new Error('Invalid check-in state.');
  }
  const note = text(data.note, 'check-in note', CHECK_IN_NOTE_MAX_LENGTH);
  return {state: state as CheckInStateId, note};
}

export function normalizeSharedCheckInNoteInput(raw: unknown): {text: string} {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new Error('Invalid shared note.');
  }
  const data = raw as Record<string, unknown>;
  const noteText = text(
    data.text,
    'shared note',
    CHECK_IN_SHARED_NOTE_MAX_LENGTH,
    true,
  );
  return {text: noteText};
}

function currentSlot(
  slot: CheckInSlotData | undefined,
  nowMs: number,
): CheckInSlotData | null {
  if (!slot) return null;
  // A slot at or past its expiry is absent, not stale.
  return slot.expiresAtMs > nowMs ? slot : null;
}

export function projectCheckIn(
  doc: CheckInDocData | null,
  uid: string,
  nowMs: number,
): ProjectedCheckIn {
  if (!doc) {
    return {otherUid: '', myState: null, otherState: null, sharedNote: null};
  }
  assertParticipant(doc.participantUids, uid);
  const otherUid = doc.participantUids.find((participant) => participant !== uid) ?? '';
  return {
    otherUid,
    myState: currentSlot(doc.states[uid], nowMs),
    otherState: otherUid ? currentSlot(doc.states[otherUid], nowMs) : null,
    sharedNote: doc.sharedNote,
  };
}

// Returns the complete states map to persist after the caller posts a
// state. Only the caller's own slot is written; the other participant's
// slot is carried over verbatim (expiry stays a read-time concern).
export function applyCheckInStateWrite(
  doc: CheckInDocData | null,
  participantUids: string[],
  uid: string,
  input: CheckInStateInput,
  nowMs: number,
): Record<string, CheckInSlotData> {
  assertParticipant(participantUids, uid);
  const states: Record<string, CheckInSlotData> = {...(doc?.states ?? {})};
  states[uid] = {
    state: input.state,
    note: input.note,
    updatedAtMs: nowMs,
    expiresAtMs: nowMs + CHECK_IN_STATE_TTL_MS,
  };
  return states;
}

export function applyClearCheckInState(
  doc: CheckInDocData | null,
  participantUids: string[],
  uid: string,
): Record<string, CheckInSlotData> {
  assertParticipant(participantUids, uid);
  const states: Record<string, CheckInSlotData> = {...(doc?.states ?? {})};
  delete states[uid];
  return states;
}

// The shared note is jointly editable by definition; attribution is part
// of the value so an edit can never be silent.
export function applySharedCheckInNoteWrite(
  participantUids: string[],
  uid: string,
  noteText: string,
  nowMs: number,
): SharedCheckInNoteData {
  assertParticipant(participantUids, uid);
  return {text: noteText, updatedByUid: uid, updatedAtMs: nowMs};
}

export function assertCheckInParticipant(
  participantUids: string[],
  uid: string,
): void {
  assertParticipant(participantUids, uid);
}

// ---------------------------------------------------------------------------
// Deletion cascades (Phase 2 spec §3.3/§3.6)
//
// A check-in is a present-tense surface with zero historical value: when a
// connection ends, a block lands, or an account is deleted, the check-in
// document is deleted outright rather than retained behind guard refusals.
// The document id IS the conversation id, so the cascade targets are a
// pure function of the affected conversation ids; the Firestore mechanics
// live in the callables (safety.ts block/end flows, index.ts deletion).

export function checkInDocIdForConversation(conversationId: string): string {
  return String(conversationId ?? '').trim();
}

// Every conversation the deleting account belongs to loses its check-in
// doc. Duplicates collapse (a conversation can surface once per query,
// but the sweep stays safe if sources ever overlap) and blank ids are
// dropped so a malformed conversation id can never widen the sweep.
export function checkInDocIdsForAccountDeletion(
  conversationIds: readonly string[],
): string[] {
  const ids = new Set<string>();
  for (const conversationId of conversationIds) {
    const id = checkInDocIdForConversation(conversationId);
    if (id) ids.add(id);
  }
  return [...ids];
}
