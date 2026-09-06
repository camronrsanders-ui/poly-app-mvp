import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const backend = fs.readFileSync(
  'functions/src/circle_membership.ts',
  'utf8',
);

const service = fs.readFileSync(
  'lib/services/circle_membership_service.dart',
  'utf8',
);

const screen = fs.readFileSync(
  'lib/screens/circle/my_circle_screen.dart',
  'utf8',
);

test('Circle member identities come from active memberships', () => {
  assert.match(
    backend,
    /circleMemberDocs/,
  );

  assert.match(
    backend,
    /doc\.get\('status'\)[\s\S]*'active'/,
  );

  assert.match(
    backend,
    /peerUid\s*!==\s*uid/,
  );
});

test('Circle members respect blocking and account availability', () => {
  assert.match(
    backend,
    /blockedCirclePeers/,
  );

  assert.match(
    backend,
    /isActiveCompliantMember/,
  );

  assert.match(
    backend,
    /blockedPeerUids\.has/,
  );
});

test('Circle member automatic view is intentionally minimal', () => {
  assert.match(
    backend,
    /function toCircleMemberView/,
  );

  assert.match(
    backend,
    /displayName/,
  );

  assert.doesNotMatch(
    backend.match(
      /function toCircleMemberView[\s\S]*?\n}/,
    )?.[0] ?? '',
    /bio|headline|orientation|relationshipStructure/,
  );
});

test('Flutter puts accepted Circle members into spatial worlds', () => {
  assert.match(
    service,
    /members/,
  );

  assert.match(
    screen,
    /circle\.members/,
  );

  assert.match(
    screen,
    /final circlePeople/,
  );

  assert.match(
    screen,
    /people:\s*circlePeople/,
  );
});

test('Circle invite action remains owner-only', () => {
  assert.match(
    screen,
    /activeCircleIsOwner/,
  );

  assert.match(
    screen,
    /activeCircleIsOwner[\s\S]*\?\s*\(\)/,
  );
});
