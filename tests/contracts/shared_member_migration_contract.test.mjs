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

test('spatial orbit exposes member positions for world migration', () => {
  assert.match(orbit, /class PolycircleSpatialOrbitController/);
  assert.match(orbit, /normalizedPositions/);
  assert.match(orbit, /_replaceNormalizedPositions/);
});

test('migrating members can be hidden from the underlying orbit', () => {
  assert.match(orbit, /hiddenItemIds/);
  assert.match(orbit, /widget\.hiddenItemIds\.contains/);
});

test('world transition detects members shared by both circles', () => {
  assert.match(circle, /targetIds/);
  assert.match(circle, /sharedCandidates/);
  assert.match(circle, /\.take\(3\)/);
});

test('migration preserves source orbital positions', () => {
  assert.match(circle, /_migrationStartPositions/);
  assert.match(circle, /_orbitController\.normalizedPositions/);
});

test('shared people travel above the changing world', () => {
  assert.match(circle, /_SharedMemberMigrationLayer/);
  assert.match(circle, /animation:\s*_worldTravel/);
  assert.match(circle, /hiddenItemIds:\s*migratingIds/);
});

test('shared world prototypes remain emulator-only', () => {
  assert.match(
    circle,
    /kDebugMode\s*&&\s*useFirebaseEmulators/,
  );
});
