const test = require('node:test');
const assert = require('node:assert/strict');
const {
  CHECK_IN_STATES,
  CHECK_IN_STATE_TTL_MS,
  applyCheckInStateWrite,
  applyClearCheckInState,
  applySharedCheckInNoteWrite,
  checkInDocIdForConversation,
  checkInDocIdsForAccountDeletion,
  emptyCheckInDoc,
  normalizeCheckInStateInput,
  normalizeSharedCheckInNoteInput,
  projectCheckIn,
} = require('../lib/connection_check_in_fields.js');

const ALICE = 'alice';
const BOB = 'bob';
const EVE = 'eve';
const PARTICIPANTS = [ALICE, BOB];
const NOW = 1_760_000_000_000;

function docWithStates() {
  return {
    participantUids: [...PARTICIPANTS],
    states: {
      [ALICE]: {
        state: 'doing_well',
        note: 'Good morning.',
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

test('state vocabulary is the six plain-language states from the spec', () => {
  assert.deepEqual(
    CHECK_IN_STATES.map((option) => [option.id, option.label]),
    [
      ['doing_well', 'Doing well'],
      ['okay', 'Okay'],
      ['tender', 'Tender / having a hard day'],
      ['need_space', 'Need space'],
      ['want_to_talk', 'Want to talk'],
      ['celebrating', 'Celebrating something'],
    ],
  );
});

test('normalizes a valid state post and trims the note', () => {
  assert.deepEqual(
    normalizeCheckInStateInput({state: ' okay ', note: '  Around later. '}),
    {state: 'okay', note: 'Around later.'},
  );
  assert.deepEqual(normalizeCheckInStateInput({state: 'doing_well'}), {
    state: 'doing_well',
    note: '',
  });
});

test('rejects unknown states and over-length notes', () => {
  assert.throws(
    () => normalizeCheckInStateInput({state: 'radiating_and_joyful'}),
    /check-in state/i,
  );
  assert.throws(
    () =>
      normalizeCheckInStateInput({state: 'okay', note: 'x'.repeat(281)}),
    /check-in note/i,
  );
});

test('rejects severe prohibited UGC in check-in and shared-note text', () => {
  assert.throws(
    () => normalizeCheckInStateInput({state: 'okay', note: 'I will kill you'}),
    /prohibited content/i,
  );
  assert.throws(
    () => normalizeSharedCheckInNoteInput({text: 'kill yourself'}),
    /prohibited content/i,
  );
});

test('shared note input requires text within the limit', () => {
  assert.deepEqual(normalizeSharedCheckInNoteInput({text: '  Dinner at 7. '}), {
    text: 'Dinner at 7.',
  });
  assert.throws(() => normalizeSharedCheckInNoteInput({text: '   '}), /shared note/i);
  assert.throws(
    () => normalizeSharedCheckInNoteInput({text: 'x'.repeat(281)}),
    /shared note/i,
  );
});

test('projects both current states relative to the caller', () => {
  const projected = projectCheckIn(docWithStates(), ALICE, NOW);
  assert.equal(projected.otherUid, BOB);
  assert.equal(projected.myState.state, 'doing_well');
  assert.equal(projected.otherState.state, 'tender');

  const fromBob = projectCheckIn(docWithStates(), BOB, NOW);
  assert.equal(fromBob.otherUid, ALICE);
  assert.equal(fromBob.myState.state, 'tender');
  assert.equal(fromBob.otherState.state, 'doing_well');
});

test('an expired state projects as absent, never as a stale state', () => {
  const doc = docWithStates();
  doc.states[ALICE] = {
    state: 'need_space',
    note: '',
    updatedAtMs: NOW - CHECK_IN_STATE_TTL_MS - 1_000,
    expiresAtMs: NOW - 1_000,
  };
  // Boundary: a slot expiring exactly now is already absent.
  doc.states[BOB] = {
    state: 'okay',
    note: '',
    updatedAtMs: NOW - CHECK_IN_STATE_TTL_MS,
    expiresAtMs: NOW,
  };
  const projected = projectCheckIn(doc, ALICE, NOW);
  assert.equal(projected.myState, null);
  assert.equal(projected.otherState, null);
});

test('a missing document projects as an empty check-in', () => {
  assert.deepEqual(projectCheckIn(null, ALICE, NOW), {
    otherUid: '',
    myState: null,
    otherState: null,
    sharedNote: null,
  });
});

test('projection rejects non-participants', () => {
  assert.throws(() => projectCheckIn(docWithStates(), EVE, NOW), /participants/i);
});

test('a state write replaces only the caller slot and sets a 24h expiry', () => {
  const doc = docWithStates();
  const states = applyCheckInStateWrite(
    doc,
    PARTICIPANTS,
    ALICE,
    {state: 'celebrating', note: 'Got the job!'},
    NOW,
  );
  assert.deepEqual(states[ALICE], {
    state: 'celebrating',
    note: 'Got the job!',
    updatedAtMs: NOW,
    expiresAtMs: NOW + CHECK_IN_STATE_TTL_MS,
  });
  // The other slot is carried over verbatim, even untouched fields.
  assert.deepEqual(states[BOB], doc.states[BOB]);
});

test('a state write never writes another participant slot', () => {
  const doc = docWithStates();
  const states = applyCheckInStateWrite(
    doc,
    PARTICIPANTS,
    BOB,
    {state: 'want_to_talk', note: ''},
    NOW,
  );
  assert.deepEqual(states[ALICE], doc.states[ALICE]);
  assert.equal(states[BOB].state, 'want_to_talk');
});

test('a state write can create the states map on a fresh document', () => {
  const states = applyCheckInStateWrite(
    null,
    PARTICIPANTS,
    ALICE,
    {state: 'okay', note: ''},
    NOW,
  );
  assert.deepEqual(Object.keys(states), [ALICE]);
  assert.equal(states[ALICE].expiresAtMs, NOW + CHECK_IN_STATE_TTL_MS);
});

test('state writes reject non-participants', () => {
  assert.throws(
    () =>
      applyCheckInStateWrite(
        docWithStates(),
        PARTICIPANTS,
        EVE,
        {state: 'okay', note: ''},
        NOW,
      ),
    /participants/i,
  );
  assert.throws(
    () => applyClearCheckInState(docWithStates(), PARTICIPANTS, EVE),
    /participants/i,
  );
});

test('clearing removes only the caller slot', () => {
  const doc = docWithStates();
  const states = applyClearCheckInState(doc, PARTICIPANTS, ALICE);
  assert.equal(states[ALICE], undefined);
  assert.deepEqual(states[BOB], doc.states[BOB]);
});

test('shared note writes carry attribution and reject non-participants', () => {
  const note = applySharedCheckInNoteWrite(
    PARTICIPANTS,
    BOB,
    'Running late Friday, still on for dinner.',
    NOW,
  );
  assert.deepEqual(note, {
    text: 'Running late Friday, still on for dinner.',
    updatedByUid: BOB,
    updatedAtMs: NOW,
  });
  assert.throws(
    () => applySharedCheckInNoteWrite(PARTICIPANTS, EVE, 'Hi.', NOW),
    /participants/i,
  );
});

test('an empty doc scaffold keeps both participants and no content', () => {
  assert.deepEqual(emptyCheckInDoc(PARTICIPANTS), {
    participantUids: PARTICIPANTS,
    states: {},
    sharedNote: null,
  });
});

test('block/end cascade targets exactly the pair conversation doc', () => {
  // blockUser/endConnection act on the pair id, which is also the
  // conversation id and therefore the check-in doc id (spec §3.1/§3.6).
  assert.equal(checkInDocIdForConversation('alice_bob'), 'alice_bob');
  assert.equal(checkInDocIdForConversation('  alice_bob  '), 'alice_bob');
  assert.equal(checkInDocIdForConversation(''), '');
});

test('account-deletion cascade targets every conversation the account is in', () => {
  assert.deepEqual(
    checkInDocIdsForAccountDeletion(['alice_bob', 'alice_carol']),
    ['alice_bob', 'alice_carol'],
  );
});

test('account-deletion cascade dedupes and drops blank conversation ids', () => {
  assert.deepEqual(
    checkInDocIdsForAccountDeletion(['alice_bob', 'alice_bob', ' ', '']),
    ['alice_bob'],
  );
  assert.deepEqual(checkInDocIdsForAccountDeletion([]), []);
});
