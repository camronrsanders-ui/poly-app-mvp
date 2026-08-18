const test = require('node:test');
const assert = require('node:assert/strict');
const {
  discoverPageSize,
  discoverSessionLifetimeMs,
  isValidDiscoverCursorToken,
  maximumDiscoverCandidatePool,
  normalizeDiscoverPageLimit,
  uniqueDiscoverCandidateUids,
} = require('../lib/discovery_pagination.js');

test('Discover uses fixed bounded first-release paging values', () => {
  assert.equal(discoverPageSize, 15);
  assert.equal(maximumDiscoverCandidatePool, 120);
  assert.equal(discoverSessionLifetimeMs, 30 * 60_000);
  assert.equal(normalizeDiscoverPageLimit(undefined), 15);
  assert.equal(normalizeDiscoverPageLimit(1000), 15);
  assert.equal(normalizeDiscoverPageLimit(0), 1);
  assert.equal(normalizeDiscoverPageLimit('bad'), 15);
});

test('only opaque auto-ID-shaped cursor tokens are accepted', () => {
  assert.equal(isValidDiscoverCursorToken('A1b2C3d4E5f6G7h8I9j0'), true);
  assert.equal(isValidDiscoverCursorToken('candidate-uid:latitude:12.3'), false);
  assert.equal(isValidDiscoverCursorToken('../other-member'), false);
  assert.equal(isValidDiscoverCursorToken('short'), false);
  assert.equal(isValidDiscoverCursorToken({token: 'structured'}), false);
});

test('candidate session identities are bounded and de-duplicated by UID', () => {
  assert.deepEqual(
    uniqueDiscoverCandidateUids(['a', 'b', 'a', 'c']),
    ['a', 'b', 'c'],
  );
  assert.equal(uniqueDiscoverCandidateUids(['']), null);
  assert.equal(uniqueDiscoverCandidateUids([7]), null);
  assert.equal(
    uniqueDiscoverCandidateUids(
      Array.from({length: maximumDiscoverCandidatePool + 1}, (_, index) => `u${index}`),
    ),
    null,
  );
});
