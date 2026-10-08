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
