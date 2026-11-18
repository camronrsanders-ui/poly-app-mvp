const test = require('node:test');
const assert = require('node:assert/strict');
const {
  machineRejectionReasonCodes,
  moderatorRejectionReasonCodes,
  fallbackRejectionReasonCode,
  rejectionReasonCodeForDisplay,
  moderatorRejectionReasonToStore,
} = require('../lib/profile_media_rejection.js');

// H-9 (photo uploads PR 2): the rejection-reason taxonomy. These are
// the first unit tests for the photo backend. The stored
// `rejectionReason` field mixes five machine codes, the adopted
// moderator codes, legacy free text, the QA string
// 'local_moderation_qa', and the bare 'moderation' default; the
// member-facing listing may only ever carry a display-safe code, and
// the review callable may only ever store an adopted moderator code.

test('the adopted taxonomies are exactly the designed code sets', () => {
  assert.deepEqual([...machineRejectionReasonCodes], [
    'upload_validation',
    'invalid_processing_state',
    'storage_validation',
    'content_type_mismatch',
    'image_processing',
  ]);
  assert.deepEqual([...moderatorRejectionReasonCodes], [
    'community_guidelines',
    'image_quality',
    'other_policy',
  ]);
  assert.equal(fallbackRejectionReasonCode, 'moderation_policy');
});

test('every machine rejection code passes through to the display taxonomy', () => {
  for (const code of machineRejectionReasonCodes) {
    assert.equal(rejectionReasonCodeForDisplay(code), code);
  }
});

test('every moderator rejection code passes through to the display taxonomy', () => {
  for (const code of moderatorRejectionReasonCodes) {
    assert.equal(rejectionReasonCodeForDisplay(code), code);
  }
});

test('the fallback code itself passes through to the display taxonomy', () => {
  assert.equal(rejectionReasonCodeForDisplay('moderation_policy'), 'moderation_policy');
});

test('legacy stored values map to the generic policy code, never raw', () => {
  // The pre-taxonomy default, the QA client's hard-coded string, and
  // arbitrary free text a reviewer once typed must not reach a member.
  assert.equal(rejectionReasonCodeForDisplay('moderation'), 'moderation_policy');
  assert.equal(rejectionReasonCodeForDisplay('local_moderation_qa'), 'moderation_policy');
  assert.equal(
    rejectionReasonCodeForDisplay('Does not look like a real person, repeat offender'),
    'moderation_policy',
  );
  assert.equal(rejectionReasonCodeForDisplay('COMMUNITY_GUIDELINES'), 'moderation_policy');
});

test('missing and non-string stored values map to the generic policy code', () => {
  assert.equal(rejectionReasonCodeForDisplay(undefined), 'moderation_policy');
  assert.equal(rejectionReasonCodeForDisplay(null), 'moderation_policy');
  assert.equal(rejectionReasonCodeForDisplay(''), 'moderation_policy');
  assert.equal(rejectionReasonCodeForDisplay(42), 'moderation_policy');
  assert.equal(rejectionReasonCodeForDisplay({reason: 'image_quality'}), 'moderation_policy');
  assert.equal(rejectionReasonCodeForDisplay(['image_quality']), 'moderation_policy');
});

test('the review callable stores an adopted moderator code as itself', () => {
  for (const code of moderatorRejectionReasonCodes) {
    assert.equal(moderatorRejectionReasonToStore(code), code);
  }
});

test('the review callable stores anything outside the moderator set as the generic policy code', () => {
  assert.equal(moderatorRejectionReasonToStore(undefined), 'moderation_policy');
  assert.equal(moderatorRejectionReasonToStore(''), 'moderation_policy');
  assert.equal(moderatorRejectionReasonToStore('moderation'), 'moderation_policy');
  assert.equal(moderatorRejectionReasonToStore('local_moderation_qa'), 'moderation_policy');
  assert.equal(moderatorRejectionReasonToStore('free text from a reviewer'), 'moderation_policy');
  // A moderator cannot mint a machine code, and the fallback is not a
  // selectable code — both land on the same stored fallback value.
  assert.equal(moderatorRejectionReasonToStore('image_processing'), 'moderation_policy');
  assert.equal(moderatorRejectionReasonToStore('upload_validation'), 'moderation_policy');
  assert.equal(moderatorRejectionReasonToStore('moderation_policy'), 'moderation_policy');
  assert.equal(moderatorRejectionReasonToStore(42), 'moderation_policy');
  assert.equal(moderatorRejectionReasonToStore(null), 'moderation_policy');
});
