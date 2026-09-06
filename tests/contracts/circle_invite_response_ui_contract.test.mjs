import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const screen = fs.readFileSync(
  'lib/screens/circle/my_circle_screen.dart',
  'utf8',
);

test('incoming invitations are part of the universe model', () => {
  assert.match(
    screen,
    /List<CircleInviteSummary> invites/,
  );

  assert.match(
    screen,
    /circleSnapshot\.invites/,
  );
});

test('recipient can accept or decline', () => {
  assert.match(
    screen,
    /class _IncomingCircleInvitesSheet/,
  );

  assert.match(
    screen,
    /'Accept'/,
  );

  assert.match(
    screen,
    /'Decline'/,
  );

  assert.match(
    screen,
    /respondToInvite/,
  );
});

test('accepted Circle becomes active only after backend response', () => {
  const responseMethod =
    screen.match(
      /Future<void> _respondToCircleInvitation\([\s\S]*?Future<void> _openCircleInvitations/,
    )?.[0] ?? '';

  assert.ok(
    responseMethod.length > 0,
    'Circle invitation response method must exist',
  );

  assert.match(
    responseMethod,
    /respondToInvite/,
  );

  assert.match(
    responseMethod,
    /if\s*\(\s*accepted\s*\)/,
  );

  assert.match(
    responseMethod,
    /_activeWorldId\s*=/,
  );

  assert.match(
    responseMethod,
    /circle:\$\{invite\.circleId\}/,
  );
});
