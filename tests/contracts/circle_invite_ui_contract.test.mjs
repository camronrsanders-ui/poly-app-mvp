import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const screen = fs.readFileSync(
  'lib/screens/circle/my_circle_screen.dart',
  'utf8',
);

test('real Circle exposes an invitation experience', () => {
  assert.match(
    screen,
    /Future<void> _inviteToCircle/,
  );

  assert.match(
    screen,
    /class _InviteCircleMemberSheet/,
  );

  assert.match(
    screen,
    /Invite people/,
  );
});

test('Circle invite uses existing connection identity', () => {
  assert.match(
    screen,
    /inviteMember\(/,
  );

  assert.match(
    screen,
    /inviteeUid:/,
  );

  assert.match(
    screen,
    /model\.connections/,
  );
});

test('invitation UI explicitly preserves consent', () => {
  assert.match(
    screen,
    /does not add them/i,
  );

  assert.match(
    screen,
    /only after accepting/i,
  );
});

test('sending an invitation does not locally add a Circle member', () => {
  const inviteMethod =
      screen.match(
        /Future<void> _inviteToCircle[\s\S]*?\n  }\n\n  Future<void> _openSafety/,
      )?.[0] ?? '';

  assert.doesNotMatch(
    inviteMethod,
    /\.add\(person\)/,
  );

  assert.doesNotMatch(
    inviteMethod,
    /memberCount\s*\+\+/,
  );
});

test('populated Circle universe exposes the invite affordance', () => {
  // The empty-stage invite was the only wiring before Step 2
  // Item 3; the populated universe's Circle options menu now
  // carries the same invite through the header actions.
  assert.match(
    screen,
    /Invite to this Circle/,
  );

  assert.match(
    screen,
    /onInviteToCircle/,
  );

  assert.match(
    screen,
    /_circleHeader/,
  );
});

test('populated Circle universe wires Leave and Archive actions', () => {
  assert.match(
    screen,
    /Leave this Circle/,
  );

  assert.match(
    screen,
    /Archive this Circle/,
  );

  // Leave goes through the membership service callable path,
  // behind the same injection pattern as invite and respond.
  assert.match(
    screen,
    /leaveCircleAction/,
  );

  assert.match(
    screen,
    /\.leaveCircle\(/,
  );

  assert.match(
    screen,
    /archiveCircleAction/,
  );

  assert.match(
    screen,
    /unarchiveCircleAction/,
  );

  assert.match(
    screen,
    /Archived Circles/,
  );
});
