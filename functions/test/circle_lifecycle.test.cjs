const test = require('node:test');
const assert = require('node:assert/strict');
const {
  evaluateArchiveCircle,
  evaluateUnarchiveCircle,
  shouldExpireInviteOnArchive,
  isOwnerArchivedCircle,
} = require('../lib/circle_lifecycle.js');

// The archive / restore decision matrix (Step 2, Item 3). The owner
// is identified by the same double check leaveCircle uses: the
// membership role AND the Circle's ownerUid must both name the
// caller.

const ownerFacts = {
  circleExists: true,
  membershipExists: true,
  membershipRole: 'owner',
  circleOwnerUid: 'owner-1',
  circleStatus: 'active',
  uid: 'owner-1',
};

test('the owner can archive an active Circle', () => {
  assert.deepEqual(evaluateArchiveCircle(ownerFacts), {
    action: 'proceed',
  });
});

test('archiving an already archived Circle is a no-op', () => {
  assert.deepEqual(
    evaluateArchiveCircle({
      ...ownerFacts,
      circleStatus: 'archived',
    }),
    {action: 'noop'},
  );
});

test('a member cannot archive a Circle', () => {
  assert.deepEqual(
    evaluateArchiveCircle({
      ...ownerFacts,
      membershipRole: 'member',
      uid: 'member-1',
    }),
    {
      action: 'deny',
      code: 'permission-denied',
      message: 'Only the Circle owner can archive this Circle.',
    },
  );
});

test('an owner role alone is not enough when ownerUid disagrees', () => {
  const verdict = evaluateArchiveCircle({
    ...ownerFacts,
    circleOwnerUid: 'someone-else',
  });

  assert.equal(verdict.action, 'deny');
  assert.equal(verdict.code, 'permission-denied');
});

test('an ownerUid match alone is not enough without the owner role', () => {
  const verdict = evaluateArchiveCircle({
    ...ownerFacts,
    membershipRole: 'member',
  });

  assert.equal(verdict.action, 'deny');
  assert.equal(verdict.code, 'permission-denied');
});

test('a non-member is told the membership was not found', () => {
  assert.deepEqual(
    evaluateArchiveCircle({
      ...ownerFacts,
      membershipExists: false,
      membershipRole: undefined,
      uid: 'stranger-1',
    }),
    {
      action: 'deny',
      code: 'not-found',
      message: 'Circle membership was not found.',
    },
  );
});

test('a missing Circle is told the membership was not found', () => {
  const verdict = evaluateArchiveCircle({
    ...ownerFacts,
    circleExists: false,
  });

  assert.equal(verdict.action, 'deny');
  assert.equal(verdict.code, 'not-found');
});

test('an unrecognized Circle status refuses archive', () => {
  const verdict = evaluateArchiveCircle({
    ...ownerFacts,
    circleStatus: 'suspended',
  });

  assert.equal(verdict.action, 'deny');
  assert.equal(verdict.code, 'failed-precondition');
});

test('the owner can restore an archived Circle', () => {
  assert.deepEqual(
    evaluateUnarchiveCircle({
      ...ownerFacts,
      circleStatus: 'archived',
    }),
    {action: 'proceed'},
  );
});

test('restoring an already active Circle is a no-op', () => {
  assert.deepEqual(evaluateUnarchiveCircle(ownerFacts), {
    action: 'noop',
  });
});

test('a member cannot restore an archived Circle', () => {
  assert.deepEqual(
    evaluateUnarchiveCircle({
      ...ownerFacts,
      membershipRole: 'member',
      circleStatus: 'archived',
      uid: 'member-1',
    }),
    {
      action: 'deny',
      code: 'permission-denied',
      message: 'Only the Circle owner can restore this Circle.',
    },
  );
});

test('a non-member cannot restore an archived Circle', () => {
  const verdict = evaluateUnarchiveCircle({
    ...ownerFacts,
    membershipExists: false,
    membershipRole: undefined,
    circleStatus: 'archived',
    uid: 'stranger-1',
  });

  assert.equal(verdict.action, 'deny');
  assert.equal(verdict.code, 'not-found');
});

test('an unrecognized Circle status refuses restore', () => {
  const verdict = evaluateUnarchiveCircle({
    ...ownerFacts,
    circleStatus: 'suspended',
  });

  assert.equal(verdict.action, 'deny');
  assert.equal(verdict.code, 'failed-precondition');
});

test('only pending invitations expire on archive', () => {
  assert.equal(shouldExpireInviteOnArchive('pending'), true);
  assert.equal(shouldExpireInviteOnArchive('accepted'), false);
  assert.equal(shouldExpireInviteOnArchive('declined'), false);
  assert.equal(shouldExpireInviteOnArchive('expired'), false);
  assert.equal(shouldExpireInviteOnArchive(undefined), false);
});

test('the archived list shows only the owner their archived Circles', () => {
  assert.equal(isOwnerArchivedCircle('archived', 'owner-1', 'owner-1'), true);
  assert.equal(isOwnerArchivedCircle('archived', 'owner-1', 'member-1'), false);
  assert.equal(isOwnerArchivedCircle('active', 'owner-1', 'owner-1'), false);
  assert.equal(isOwnerArchivedCircle(undefined, 'owner-1', 'owner-1'), false);
});
