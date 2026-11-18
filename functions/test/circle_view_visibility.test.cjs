const test = require('node:test');
const assert = require('node:assert/strict');
const {
  circleProfileVisibilityDenial,
} = require('../lib/circle_view_visibility.js');

// The viewer matrix for the profile-visibility cap in getCircleForProfile
// (H-11): profileVisibility x match state for a non-owner. The owner never
// reaches the cap (the callable skips it when requester == owner).

test('public profiles impose no cap, matched or not', () => {
  assert.equal(circleProfileVisibilityDenial('public', true), null);
  assert.equal(circleProfileVisibilityDenial('public', false), null);
});

test('connections-only profiles require an active match', () => {
  assert.equal(circleProfileVisibilityDenial('matches_only', true), null);
  assert.equal(
    circleProfileVisibilityDenial('matches_only', false),
    'Circle is available to connections only.',
  );
});

test('hidden profiles deny every non-owner with the generic message', () => {
  assert.equal(
    circleProfileVisibilityDenial('hidden', true),
    'Circle is unavailable.',
  );
  assert.equal(
    circleProfileVisibilityDenial('hidden', false),
    'Circle is unavailable.',
  );
});

test('a missing profileVisibility field fails closed as hidden', () => {
  assert.equal(
    circleProfileVisibilityDenial(undefined, true),
    'Circle is unavailable.',
  );
  assert.equal(
    circleProfileVisibilityDenial(undefined, false),
    'Circle is unavailable.',
  );
  assert.equal(
    circleProfileVisibilityDenial(null, true),
    'Circle is unavailable.',
  );
});

test('unrecognized profileVisibility values fail closed', () => {
  for (const value of ['friends_only', '', 'PUBLIC', 'Matches_Only', 42, true]) {
    assert.equal(
      circleProfileVisibilityDenial(value, true),
      'Circle is unavailable.',
    );
    assert.equal(
      circleProfileVisibilityDenial(value, false),
      'Circle is unavailable.',
    );
  }
});
