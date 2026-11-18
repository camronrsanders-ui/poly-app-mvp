import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

const callables = read('functions/src/connection_check_ins.ts');
const writes = read('functions/src/connection_check_in_writes.ts');
const fields = read('functions/src/connection_check_in_fields.ts');
const rules = read('firestore.rules');

function handlerSection(name, nextName) {
  const pattern = nextName
    ? new RegExp(`export const ${name}[\\s\\S]*?export const ${nextName}`)
    : new RegExp(`export const ${name}[\\s\\S]*$`);
  return callables.match(pattern)?.[0] ?? '';
}

const writeHandlers = [
  {
    name: 'setMyCheckInState',
    next: 'clearMyCheckInState',
    commit: 'commitCheckInStateWrite',
  },
  {
    name: 'clearMyCheckInState',
    next: 'setSharedCheckInNote',
    commit: 'commitClearCheckInState',
  },
  {
    name: 'setSharedCheckInNote',
    next: 'clearSharedCheckInNote',
    commit: 'commitSharedCheckInNoteWrite',
  },
  {
    name: 'clearSharedCheckInNote',
    next: null,
    commit: 'commitClearSharedCheckInNote',
  },
];

for (const handler of writeHandlers) {
  test(`${handler.name} delegates to the transactional orchestration`, () => {
    const section = handlerSection(handler.name, handler.next);
    assert.ok(section, `handler ${handler.name} not found`);
    assert.match(section, new RegExp(`${handler.commit}\\(`));
    assert.match(section, /firestoreCheckInWriteStore\(db, participantUids\)/);
    // The handler itself must not touch the check-in document: no
    // collection access, no bare ref get/set. All document access
    // lives in the transactional binding.
    assert.doesNotMatch(section, /collection\('connection_check_ins'\)/);
    assert.doesNotMatch(section, /\bref\.(?:get|set)\(/);
  });
}

test('no bare check-in document get/set outside a transaction (negative pin)', () => {
  // The H-3 defect shape: a handler-scoped ref read with ref.get()
  // and written back with ref.set() from a stale snapshot. Neither
  // may reappear anywhere in the callable layer. (getCheckIn's read
  // is a chained one-shot read in the read callable, not this shape,
  // and the rate limiter's ref lives in its own transaction.)
  assert.doesNotMatch(
    callables,
    /const ref = db\.collection\('connection_check_ins'\)/,
  );
  assert.doesNotMatch(callables, /await ref\.(?:get|set)\(/);

  // The only transactional document accesses are the binding's.
  assert.match(
    callables,
    /tx\.get\(\s*db\.collection\('connection_check_ins'\)\.doc\(conversationId\)/,
  );
  assert.match(
    callables,
    /tx\.set\(\s*db\.collection\('connection_check_ins'\)\.doc\(conversationId\)/,
  );
});

test('every write operation routes through runTransaction exactly once', () => {
  const calls = writes.match(/store\.runTransaction/g) ?? [];
  assert.equal(calls.length, 4);
  for (const name of [
    'commitCheckInStateWrite',
    'commitClearCheckInState',
    'commitSharedCheckInNoteWrite',
    'commitClearSharedCheckInNote',
  ]) {
    assert.match(writes, new RegExp(`export async function ${name}\\(`));
  }
});

test('the orchestration composes through the pure fields module, never around it', () => {
  assert.match(writes, /applyCheckInStateWrite\(/);
  assert.match(writes, /applyClearCheckInState\(/);
  assert.match(writes, /applySharedCheckInNoteWrite\(/);
  // The module is store-agnostic: no Firestore imports or access, so
  // the fake-store suite exercises the real orchestration code.
  assert.doesNotMatch(writes, /firebase-admin|firebase-functions|getFirestore/);
  assert.doesNotMatch(writes, /\.collection\(/);
});

test('both clear operations no-op on a missing document inside the transaction', () => {
  const noOps = writes.match(/if \(doc === null\) return;/g) ?? [];
  assert.equal(noOps.length, 2);
});

test('the persisted check-in data shape is unchanged by the transactional move', () => {
  // Same fields, same merge semantics, createdAt only on first write,
  // note removal still a field delete.
  assert.match(callables, /updatedAt: FieldValue\.serverTimestamp\(\)/);
  assert.match(callables, /payload\.participantUids = participantUids/);
  assert.match(callables, /payload\.createdAt = FieldValue\.serverTimestamp\(\)/);
  assert.match(callables, /payload\.states = statesForFirestore\(write\.states\)/);
  assert.match(callables, /payload\.sharedNote = FieldValue\.delete\(\)/);
  assert.match(callables, /\{merge: true\}/);
  // The 24h read-time expiry and the client-denied rules posture are
  // untouched.
  assert.match(fields, /CHECK_IN_STATE_TTL_MS = 24 \* 60 \* 60_000/);
  assert.match(
    rules,
    /match \/connection_check_ins\/\{conversationId\} \{ allow read, write: if false; \}/,
  );
});
