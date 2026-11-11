import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

// Orbit Phase 0 (2026-11-11): truthfulness, accessibility, and
// navigation for the Circle orbit — reduced motion, focus anchored
// to identity, and reachability past the render cap. These contracts
// pin the mechanisms; behavior is covered by the Dart widget tests.

const orbit = fs.readFileSync(
  'lib/widgets/polycircle_spatial_orbit.dart',
  'utf8',
);

const circle = fs.readFileSync(
  'lib/screens/circle/my_circle_screen.dart',
  'utf8',
);

test('Circle orbit honors platform reduced-motion signals', () => {
  assert.match(orbit, /disableAnimations/);
  assert.match(orbit, /accessibleNavigation/);
  assert.match(orbit, /_reduceMotion/);
});

test('Circle orbit focus is anchored to a person, not a list position', () => {
  assert.match(orbit, /_focusedId/);
  assert.match(orbit, /newIds\.indexOf\(previousId\)/);
});

test('the render cap bounds rendering, never membership', () => {
  assert.match(orbit, /maxVisibleItems/);
  assert.match(orbit, /void focusItem\(/);
  assert.match(orbit, /_ensureWindowContains/);
});

test('My Circle offers non-orbit paths to every person', () => {
  assert.match(circle, /Previous person/);
  assert.match(circle, /Next person/);
  assert.match(circle, /Everyone in/);
});

test('world travel honors reduced motion', () => {
  assert.match(circle, /_reduceMotion/);
  assert.match(circle, /disableAnimations/);
});

test('sparse Circle populations get portrait treatment', () => {
  assert.match(orbit, /class SpatialOrbitVisuals/);
  assert.match(orbit, /baseNodeSize/);
});
