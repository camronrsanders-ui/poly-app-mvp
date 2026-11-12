import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

// Production policy (Orbit Phase 0, 2026-11-11): My Circle topology
// is NOT emulator-only. In every build, the owner's orbit draws
// owner-to-member "Connected" edges for confirmed mutual connections
// present in the current world — and nothing else: group membership
// alone never makes an edge, and no relationship card is consulted.
// The only emulator-gated content on this screen is the synthetic
// preview worlds (House / Chosen Family) in _worlds(). An earlier
// version of this file claimed topology was emulator-only by matching
// the preview worlds' gate; that claim was wrong and is corrected
// by the tests below.

const circle = fs.readFileSync(
  'lib/screens/circle/my_circle_screen.dart',
  'utf8',
);

const orbit = fs.readFileSync(
  'lib/widgets/polycircle_spatial_orbit.dart',
  'utf8',
);

test('spatial orbit exposes explicit topology links', () => {
  assert.match(
    orbit,
    /class PolycircleTopologyLink/,
  );

  assert.match(
    orbit,
    /topologyLinks/,
  );
});

test('topology renders as curved spatial paths', () => {
  assert.match(
    orbit,
    /class _TopologyPainter/,
  );

  assert.match(
    orbit,
    /quadraticBezierTo/,
  );
});

test('focused people emphasize only relevant paths', () => {
  assert.match(
    orbit,
    /focusedId/,
  );

  assert.match(
    orbit,
    /active/,
  );
});

test('relationship labels render above the spatial scene', () => {
  assert.match(
    orbit,
    /class _TopologyLabelPainter/,
  );

  assert.match(
    orbit,
    /link\.label/,
  );
});

test('topology can connect YOU to another member', () => {
  assert.match(
    orbit,
    /__owner__/,
  );
});

test('production topology is built from confirmed connections in every build', () => {
  const start = circle.indexOf(
    'List<PolycircleTopologyLink> _visibleTopologyFor',
  );
  const end = circle.indexOf(
    'String _uidOf',
    start,
  );
  const visibleTopology = circle.slice(start, end);

  assert.match(
    visibleTopology,
    /confirmedConnectionTopology\(/,
  );

  // The builder runs ungated in production: confirmed mutual
  // connections are a fact in every build, not an emulator feature.
  assert.doesNotMatch(
    visibleTopology,
    /kDebugMode|useFirebaseEmulators/,
  );
});

test('the only emulator-gated Circle content is the synthetic preview worlds', () => {
  const start = circle.indexOf(
    'List<_CircleWorld> _worlds(',
  );
  const end = circle.indexOf(
    'List<PolycircleTopologyLink> _visibleTopologyFor',
    start,
  );
  const worlds = circle.slice(start, end);

  assert.match(
    worlds,
    /kDebugMode\s*&&\s*useFirebaseEmulators/,
  );
});

test('topology links run only from the owner to confirmed, visible members', () => {
  const topology = fs.readFileSync(
    'lib/screens/circle/confirmed_connection_topology.dart',
    'utf8',
  );

  assert.match(topology, /fromId: '__owner__'/);
  assert.match(topology, /label: 'Connected'/);
  assert.match(topology, /confirmed\.contains\(uid\)/);
});

test('production topology does not infer consent from relationship cards', () => {
  assert.doesNotMatch(
    circle,
    /RelationshipCardService/,
  );
});
