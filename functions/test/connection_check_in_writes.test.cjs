const test = require('node:test');
const assert = require('node:assert/strict');
const {
  commitCheckInStateWrite,
  commitClearCheckInState,
  commitSharedCheckInNoteWrite,
  commitClearSharedCheckInNote,
} = require('../lib/connection_check_in_writes.js');
const {
  CHECK_IN_STATE_TTL_MS,
} = require('../lib/connection_check_in_fields.js');

// Orchestration tests for the transactional check-in writes (H-3).
//
// The fake store below models Firestore's optimistic transaction
// semantics faithfully: a transaction snapshots the document version
// at its read; at commit, if the version moved, the whole callback
// re-runs against the fresh document and the retry is counted. A read
// barrier holds the first N transactions at their reads so the losing
// interleaving — both writers holding the same stale snapshot — is
// driven deterministically, never by timing luck: both writers read
// the stale snapshot, the first commits, the second conflicts,
// retries, re-reads (now seeing the first write), and commits.
//
// Stated limitation: this proves the orchestration composes under a
// faithful model of Firestore's retry semantics. It does not prove
// the production backend retries identically — that is what the
// emulator and staging simultaneous-post verifications are for.

const ALICE = 'alice';
const BOB = 'bob';
const EVE = 'eve';
const PARTICIPANTS = [ALICE, BOB];
const CONVERSATION = 'alice_bob';
const NOW = 1_760_000_000_000;

class FakeCheckInStore {
  constructor() {
    this.docs = new Map();
    this.versions = new Map();
    this.retries = 0;
    this.commits = 0;
    this.readBarrier = 0;
    this.readsSeen = 0;
    this.barrierWaiters = [];
  }

  // Hold the first `count` transaction reads until all of them have
  // arrived, so concurrent writers all snapshot the same stale state.
  holdFirstReads(count) {
    this.readBarrier = count;
  }

  async passReadBarrier() {
    if (this.readBarrier === 0) return;
    this.readsSeen += 1;
    if (this.readsSeen >= this.readBarrier) {
      const waiters = this.barrierWaiters.splice(0);
      for (const resolve of waiters) resolve();
      return;
    }
    await new Promise((resolve) => this.barrierWaiters.push(resolve));
  }

  async runTransaction(updateFunction) {
    for (;;) {
      const readVersions = new Map();
      const pending = [];
      const tx = {
        get: async (conversationId) => {
          // Snapshot version and content BEFORE the barrier: every
          // held writer must observe the same pre-commit state.
          if (!readVersions.has(conversationId)) {
            readVersions.set(
              conversationId,
              this.versions.get(conversationId) ?? 0,
            );
          }
          const stored = this.docs.get(conversationId);
          const snapshot = stored ? structuredClone(stored) : null;
          await this.passReadBarrier();
          return snapshot;
        },
        set: (conversationId, write) => {
          pending.push([conversationId, write]);
        },
      };
      const result = await updateFunction(tx);
      let conflict = false;
      for (const [conversationId, version] of readVersions) {
        if ((this.versions.get(conversationId) ?? 0) !== version) {
          conflict = true;
          break;
        }
      }
      if (conflict) {
        this.retries += 1;
        continue;
      }
      for (const [conversationId, write] of pending) {
        this.applyWrite(conversationId, write);
      }
      this.commits += 1;
      return result;
    }
  }

  // Mirrors the production binding's merge semantics in plain data:
  // states / sharedNote arrive as complete field values, and a delete
  // removes the note. Scaffold fields are identity data the
  // assertions do not need beyond the document existing.
  applyWrite(conversationId, write) {
    const existing = this.docs.get(conversationId);
    const doc = existing
      ? structuredClone(existing)
      : {participantUids: [...PARTICIPANTS], states: {}, sharedNote: null};
    if (write.states) doc.states = structuredClone(write.states);
    if (write.sharedNote) doc.sharedNote = structuredClone(write.sharedNote);
    if (write.deleteSharedNote) doc.sharedNote = null;
    this.docs.set(conversationId, doc);
    this.versions.set(
      conversationId,
      (this.versions.get(conversationId) ?? 0) + 1,
    );
  }

  seed(doc) {
    this.docs.set(CONVERSATION, structuredClone(doc));
    this.versions.set(CONVERSATION, 1);
  }

  doc() {
    return this.docs.get(CONVERSATION) ?? null;
  }
}

function seededDoc() {
  return {
    participantUids: [...PARTICIPANTS],
    states: {
      [ALICE]: {
        state: 'okay',
        note: '',
        updatedAtMs: NOW - 60_000,
        expiresAtMs: NOW - 60_000 + CHECK_IN_STATE_TTL_MS,
      },
      [BOB]: {
        state: 'tender',
        note: '',
        updatedAtMs: NOW - 120_000,
        expiresAtMs: NOW - 120_000 + CHECK_IN_STATE_TTL_MS,
      },
    },
    sharedNote: null,
  };
}

test('simultaneous posts from both partners both survive', async () => {
  const store = new FakeCheckInStore();
  store.holdFirstReads(2);
  await Promise.all([
    commitCheckInStateWrite(store, CONVERSATION, PARTICIPANTS, ALICE, {
      state: 'need_space',
      note: '',
    }, NOW),
    commitCheckInStateWrite(store, CONVERSATION, PARTICIPANTS, BOB, {
      state: 'doing_well',
      note: '',
    }, NOW),
  ]);
  const doc = store.doc();
  assert.equal(doc.states[ALICE].state, 'need_space');
  assert.equal(doc.states[BOB].state, 'doing_well');
  // The second committer must have conflicted and retried against the
  // first one's committed result — that retry is the whole fix.
  assert.ok(store.retries >= 1, `expected a retry, saw ${store.retries}`);
  assert.equal(store.commits, 2);
});

test('simultaneous post and clear: the post survives, the clear lands', async () => {
  const store = new FakeCheckInStore();
  store.seed(seededDoc());
  store.holdFirstReads(2);
  await Promise.all([
    commitCheckInStateWrite(store, CONVERSATION, PARTICIPANTS, ALICE, {
      state: 'need_space',
      note: '',
    }, NOW),
    commitClearCheckInState(store, CONVERSATION, PARTICIPANTS, BOB),
  ]);
  const doc = store.doc();
  assert.equal(doc.states[ALICE].state, 'need_space');
  assert.equal(doc.states[BOB], undefined);
  assert.ok(store.retries >= 1, `expected a retry, saw ${store.retries}`);
});

test('clear racing a re-post cannot resurrect the replaced state', async () => {
  // The worst H-3 variant: Bob's clear is computed from a snapshot
  // holding Alice's OLD 'okay' while Alice re-posts 'need_space'.
  // Unchecked, Bob's whole-map write restores 'okay' over the new
  // post. Transactionally, the loser retries against the committed
  // result, so Alice's current state is the one that survives.
  const store = new FakeCheckInStore();
  store.seed(seededDoc());
  store.holdFirstReads(2);
  await Promise.all([
    commitCheckInStateWrite(store, CONVERSATION, PARTICIPANTS, ALICE, {
      state: 'need_space',
      note: '',
    }, NOW),
    commitClearCheckInState(store, CONVERSATION, PARTICIPANTS, BOB),
  ]);
  const doc = store.doc();
  assert.deepEqual(doc.states[ALICE], {
    state: 'need_space',
    note: '',
    updatedAtMs: NOW,
    expiresAtMs: NOW + CHECK_IN_STATE_TTL_MS,
  });
  assert.equal(doc.states[BOB], undefined);
  assert.ok(store.retries >= 1, `expected a retry, saw ${store.retries}`);
});

test('simultaneous note and state writes keep both fields', async () => {
  const store = new FakeCheckInStore();
  store.holdFirstReads(2);
  await Promise.all([
    commitCheckInStateWrite(store, CONVERSATION, PARTICIPANTS, ALICE, {
      state: 'want_to_talk',
      note: '',
    }, NOW),
    commitSharedCheckInNoteWrite(
      store,
      CONVERSATION,
      PARTICIPANTS,
      BOB,
      'Dinner at 7?',
      NOW,
    ),
  ]);
  const doc = store.doc();
  assert.equal(doc.states[ALICE].state, 'want_to_talk');
  assert.deepEqual(doc.sharedNote, {
    text: 'Dinner at 7?',
    updatedByUid: BOB,
    updatedAtMs: NOW,
  });
  assert.ok(store.retries >= 1, `expected a retry, saw ${store.retries}`);
});

test('simultaneous clears from both partners empty the map without error', async () => {
  const store = new FakeCheckInStore();
  store.seed(seededDoc());
  store.holdFirstReads(2);
  await Promise.all([
    commitClearCheckInState(store, CONVERSATION, PARTICIPANTS, ALICE),
    commitClearCheckInState(store, CONVERSATION, PARTICIPANTS, BOB),
  ]);
  assert.deepEqual(store.doc().states, {});
  assert.ok(store.retries >= 1, `expected a retry, saw ${store.retries}`);
});

test('a first state write creates the document with a 24h expiry', async () => {
  const store = new FakeCheckInStore();
  await commitCheckInStateWrite(store, CONVERSATION, PARTICIPANTS, ALICE, {
    state: 'celebrating',
    note: 'Got the job!',
  }, NOW);
  const doc = store.doc();
  assert.deepEqual(doc.participantUids, PARTICIPANTS);
  assert.deepEqual(doc.states[ALICE], {
    state: 'celebrating',
    note: 'Got the job!',
    updatedAtMs: NOW,
    expiresAtMs: NOW + CHECK_IN_STATE_TTL_MS,
  });
  assert.equal(store.retries, 0);
});

test('clearing a state that was never posted creates nothing', async () => {
  const store = new FakeCheckInStore();
  await commitClearCheckInState(store, CONVERSATION, PARTICIPANTS, ALICE);
  assert.equal(store.doc(), null);
  assert.equal(store.commits, 1);
});

test('note write creates the document; note clear removes only the note', async () => {
  const store = new FakeCheckInStore();
  await commitSharedCheckInNoteWrite(
    store,
    CONVERSATION,
    PARTICIPANTS,
    ALICE,
    'Running late Friday.',
    NOW,
  );
  await commitCheckInStateWrite(store, CONVERSATION, PARTICIPANTS, BOB, {
    state: 'okay',
    note: '',
  }, NOW);
  await commitClearSharedCheckInNote(store, CONVERSATION);
  const doc = store.doc();
  assert.equal(doc.sharedNote, null);
  assert.equal(doc.states[BOB].state, 'okay');
});

test('clearing a note on a missing document is a no-op', async () => {
  const store = new FakeCheckInStore();
  await commitClearSharedCheckInNote(store, CONVERSATION);
  assert.equal(store.doc(), null);
});

test('a non-participant write rejects inside the transaction and writes nothing', async () => {
  const store = new FakeCheckInStore();
  await assert.rejects(
    commitCheckInStateWrite(store, CONVERSATION, PARTICIPANTS, EVE, {
      state: 'okay',
      note: '',
    }, NOW),
    /participants/i,
  );
  assert.equal(store.doc(), null);
  assert.equal(store.commits, 0);
});
