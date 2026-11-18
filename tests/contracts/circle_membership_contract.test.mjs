import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const membership = fs.existsSync(
  'functions/src/circle_membership.ts',
)
  ? fs.readFileSync(
      'functions/src/circle_membership.ts',
      'utf8',
    )
  : '';

const index = fs.readFileSync(
  'functions/src/index.ts',
  'utf8',
);

const rules = fs.readFileSync(
  'firestore.rules',
  'utf8',
);

test('Circle membership API is backend-owned', () => {
  assert.match(
    membership,
    /export const createCircle/,
  );

  assert.match(
    membership,
    /export const inviteCircleMember/,
  );

  assert.match(
    membership,
    /export const respondToCircleInvite/,
  );

  assert.match(
    membership,
    /export const leaveCircle/,
  );

  assert.match(
    membership,
    /export const archiveCircle/,
  );

  assert.match(
    membership,
    /export const unarchiveCircle/,
  );

  assert.match(
    membership,
    /export const listMyCircles/,
  );
});

test('all Circle membership callables require App Check', () => {
  const matches = membership.match(
    /enforceAppCheck:\s*true/g,
  ) ?? [];

  assert.ok(
    matches.length >= 7,
    'Every Circle membership callable must enforce App Check.',
  );
});

test('Circle actions require an active compliant account', () => {
  assert.match(
    membership,
    /assertActiveCompliantMember/,
  );
});

test('a Circle owner cannot silently add another member', () => {
  assert.match(
    membership,
    /circle_invites/,
  );

  assert.match(
    membership,
    /status:\s*'pending'/,
  );

  assert.doesNotMatch(
    membership,
    /members.*arrayUnion/,
  );
});

test('Circle invitations require an existing active connection', () => {
  assert.match(
    membership,
    /matches/,
  );

  assert.match(
    membership,
    /(?:active.*===\s*true|match\.get\(['"]active['"]\)\s*!==\s*true)/s,
  );
});

test('blocked users cannot invite each other into a Circle', () => {
  assert.match(
    membership,
    /blocks/,
  );

  assert.match(
    membership,
    /permission-denied/,
  );
});

test('membership becomes active only after invitee acceptance', () => {
  assert.match(
    membership,
    /circle_memberships/,
  );

  assert.match(
    membership,
    /role:\s*'member'/,
  );

  assert.match(
    membership,
    /status:\s*'active'/,
  );

  assert.match(
    membership,
    /acceptedAt/,
  );
});

test('members can leave a Circle without owner cooperation', () => {
  assert.match(
    membership,
    /leaveCircle/,
  );

  assert.match(
    membership,
    /leftAt/,
  );
});

test('owner exit is the archive lifecycle and leave copy names real controls', () => {
  assert.match(
    membership,
    /role:\s*'owner'/,
  );

  // The lifecycle the old placeholder copy pointed at now exists:
  // archive and restore are real, owner-gated callables whose
  // decisions come from the pure lifecycle module.
  assert.match(
    membership,
    /evaluateArchiveCircle/,
  );

  assert.match(
    membership,
    /evaluateUnarchiveCircle/,
  );

  // Archiving expires pending invitations in the same write.
  assert.match(
    membership,
    /status:\s*'expired'/,
  );

  // The owner refusal in leaveCircle names the control that
  // actually exists now, and the false placeholder copy is gone.
  assert.match(
    membership,
    /archive it from My Circle/,
  );

  assert.doesNotMatch(
    membership,
    /through its lifecycle controls/,
  );

  assert.doesNotMatch(
    membership,
    /archive\/delete\/transfer lifecycle exists/,
  );
});

test('archived Circles surface only to their owner in listMyCircles', () => {
  assert.match(
    membership,
    /archivedCircles/,
  );

  assert.match(
    membership,
    /isOwnerArchivedCircle/,
  );
});

test('archive reads invitations inside its transaction', () => {
  // A pre-transaction query would miss an invitation created
  // concurrently from another session, and that invitation
  // would survive the archive as pending (Codex P2 on PR #79).
  // The query must run through the transaction itself.
  assert.match(
    membership,
    /tx\.get\(\s*db\s*\.collection\('circle_invites'\)/,
  );
});

test('membership and invitations are not directly client-readable', () => {
  assert.match(
    rules,
    /match \/circles\/\{circleId\}/,
  );

  assert.match(
    rules,
    /match \/circle_memberships\/\{membershipId\}/,
  );

  assert.match(
    rules,
    /match \/circle_invites\/\{inviteId\}/,
  );

  assert.match(
    rules,
    /allow read,\s*write:\s*if false/,
  );
});

test('Circle membership Functions are exported', () => {
  assert.match(
    index,
    /createCircle/,
  );

  assert.match(
    index,
    /inviteCircleMember/,
  );

  assert.match(
    index,
    /respondToCircleInvite/,
  );

  assert.match(
    index,
    /leaveCircle/,
  );

  assert.match(
    index,
    /archiveCircle/,
  );

  assert.match(
    index,
    /unarchiveCircle/,
  );

  assert.match(
    index,
    /listMyCircles/,
  );
});

test('membership data is separate from relationship-card disclosure', () => {
  assert.doesNotMatch(
    membership,
    /relationship_cards/,
  );
});
