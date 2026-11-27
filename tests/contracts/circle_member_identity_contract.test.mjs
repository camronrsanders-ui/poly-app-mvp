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

test('basis is computed at render time and never stored on a person map', () => {
  // Cycle 2 privacy ruling, condition C1: no basis key may ever be
  // written onto a person map. The map leaves the orbit screen
  // through the profile handoff, and basis is an owner-private
  // orbit fact (§2D) — it is composed at render time only.
  assert.doesNotMatch(
    screen,
    /['"]basis['"]\s*:/,
  );

  assert.doesNotMatch(
    screen,
    /\[\s*['"]basis['"]\s*\]\s*=/,
  );

  // The _worlds() merge spreads only the member record and the
  // connection payload — nothing else enters the map there.
  const start = screen.indexOf(
    'List<_CircleWorld> _worlds(',
  );
  const end = screen.indexOf(
    'List<PolycircleTopologyLink> _visibleTopologyFor',
    start,
  );
  const worlds = screen.slice(start, end);

  assert.match(worlds, /\.\.\.member/);
  assert.match(worlds, /\.\.\.connection/);
  assert.doesNotMatch(worlds, /basis/i);
});

test('basis derivation reads the topology set, never person-map richness', () => {
  // Cycle 2 privacy ruling, condition C4: the basis helper's only
  // person input is the uid, checked against the topology /
  // connected-uid set. Reading the map's rich fields would
  // resurrect the field-presence shortcut the ruling forbids — a
  // sparse connection map is indistinguishable from a member
  // record, so presence of fields is not a connection signal.
  const start = screen.indexOf('String _basisLine(');

  assert.ok(start >= 0, 'basis helper missing');

  const end = screen.indexOf('\n  }', start);
  const helper = screen.slice(start, end);

  assert.match(helper, /connectedUids/);
  assert.doesNotMatch(
    helper,
    /person\[\s*['"](age|headline|relationshipStructure|relationshipStatus|displayName)['"]\s*\]/,
  );
});
