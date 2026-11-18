// Transactional orchestration for the four check-in write operations.
//
// connection_check_in_fields.ts owns the pure document logic (what the
// new states map / shared note must be, given a document). This module
// owns the concurrency discipline the callables were missing: every
// write runs inside a transaction, so the read that feeds the pure
// computation is the same snapshot the commit is checked against.
// When two partners post at the same moment, the second transaction
// retries against the first one's committed result and recomputes
// from it, instead of overwriting it from a stale snapshot — both
// updates survive, and a reported success is a true one.
//
// The store interface is deliberately narrow (runTransaction plus a
// bound transaction's get/set over plain-data documents) so the
// orchestration is unit-testable against an in-memory store that
// models Firestore's optimistic retry, with no database. The
// production binding lives in connection_check_ins.ts and converts
// to/from Firestore types at the boundary; timestamps travel as epoch
// millis here, exactly as in connection_check_in_fields.ts.

import {
  CheckInDocData,
  CheckInSlotData,
  CheckInStateInput,
  SharedCheckInNoteData,
  applyCheckInStateWrite,
  applyClearCheckInState,
  applySharedCheckInNoteWrite,
} from './connection_check_in_fields';

// One document write, in plain-data terms. The binding translates it
// into the exact Firestore payload the pre-transaction handlers wrote:
// states / sharedNote are complete field values (the states map is
// replaced wholesale with the computed map, never merged slot by
// slot), scaffold carries the conversationId / participantUids fields
// the state and note writes have always written, and stampCreatedAt
// adds the createdAt server timestamp — set only when the
// transaction's own read found no document, which is now
// transaction-consistent instead of a race between a bare get and a
// bare set.
export interface CheckInDocWrite {
  states?: Record<string, CheckInSlotData>;
  sharedNote?: SharedCheckInNoteData;
  deleteSharedNote?: boolean;
  scaffold: boolean;
  stampCreatedAt: boolean;
}

export interface CheckInWriteTransaction {
  // The document in plain-data form, or null when it does not exist.
  get(conversationId: string): Promise<CheckInDocData | null>;
  set(conversationId: string, write: CheckInDocWrite): void;
}

export interface CheckInWriteStore {
  runTransaction<T>(
    updateFunction: (tx: CheckInWriteTransaction) => Promise<T>,
  ): Promise<T>;
}

export async function commitCheckInStateWrite(
  store: CheckInWriteStore,
  conversationId: string,
  participantUids: string[],
  uid: string,
  input: CheckInStateInput,
  nowMs: number,
): Promise<void> {
  await store.runTransaction(async (tx) => {
    const doc = await tx.get(conversationId);
    const states = applyCheckInStateWrite(
      doc,
      participantUids,
      uid,
      input,
      nowMs,
    );
    tx.set(conversationId, {
      states,
      scaffold: true,
      stampCreatedAt: doc === null,
    });
  });
}

export async function commitClearCheckInState(
  store: CheckInWriteStore,
  conversationId: string,
  participantUids: string[],
  uid: string,
): Promise<void> {
  await store.runTransaction(async (tx) => {
    const doc = await tx.get(conversationId);
    // Clearing a check-in that was never posted is a successful no-op;
    // no document is created for it.
    if (doc === null) return;
    const states = applyClearCheckInState(doc, participantUids, uid);
    tx.set(conversationId, {
      states,
      scaffold: false,
      stampCreatedAt: false,
    });
  });
}

export async function commitSharedCheckInNoteWrite(
  store: CheckInWriteStore,
  conversationId: string,
  participantUids: string[],
  uid: string,
  text: string,
  nowMs: number,
): Promise<void> {
  await store.runTransaction(async (tx) => {
    const doc = await tx.get(conversationId);
    const sharedNote = applySharedCheckInNoteWrite(
      participantUids,
      uid,
      text,
      nowMs,
    );
    tx.set(conversationId, {
      sharedNote,
      scaffold: true,
      stampCreatedAt: doc === null,
    });
  });
}

export async function commitClearSharedCheckInNote(
  store: CheckInWriteStore,
  conversationId: string,
): Promise<void> {
  await store.runTransaction(async (tx) => {
    const doc = await tx.get(conversationId);
    if (doc === null) return;
    tx.set(conversationId, {
      deleteSharedNote: true,
      scaffold: false,
      stampCreatedAt: false,
    });
  });
}
