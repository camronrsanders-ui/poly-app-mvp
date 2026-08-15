import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

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

test('My Circle topology remains emulator-only', () => {
  assert.match(
    circle,
    /_visibleTopologyFor/,
  );

  assert.match(
    circle,
    /kDebugMode\s*&&\s*useFirebaseEmulators/,
  );
});

test('production topology does not infer consent from relationship cards', () => {
  assert.doesNotMatch(
    circle,
    /RelationshipCardService/,
  );
});
