import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const orbit = fs.readFileSync(
  'lib/widgets/polycircle_spatial_orbit.dart',
  'utf8',
);

test('spatial orbit uses a camera projection', () => {
  assert.match(orbit, /class _OrbitProjector/);
  assert.match(orbit, /cameraDistance/);
  assert.match(orbit, /focalLength/);
  assert.match(orbit, /worldX/);
  assert.match(orbit, /worldZ/);
  assert.match(orbit, /perspective/);
});

test('spatial orbit models near and far depth', () => {
  assert.match(orbit, /\bbackNodes\b/);
  assert.match(orbit, /\bfrontNodes\b/);
  assert.match(orbit, /node\.depth\s*<\s*0/);
  assert.match(orbit, /node\.depth\s*>=\s*0/);
  assert.match(orbit, /\bdepth01\b/);
});

test('owner renders between rear and foreground layers', () => {
  const backLoop = orbit.search(
    /for\s*\(\s*final\s+node\s+in\s+backNodes\s*\)/,
  );

  const centerSphere = orbit.search(
    /widget\s*\.\s*centerBuilder/,
  );

  const frontLoop = orbit.search(
    /for\s*\(\s*final\s+node\s+in\s+frontNodes\s*\)/,
  );

  assert.ok(
    backLoop >= 0,
    'rear-member render layer missing',
  );

  assert.ok(
    centerSphere >= 0,
    'owner center sphere missing',
  );

  assert.ok(
    frontLoop >= 0,
    'foreground-member render layer missing',
  );

  assert.ok(
    backLoop < centerSphere &&
      centerSphere < frontLoop,
    'owner must render between rear and foreground members',
  );
});

test('orbital rail has independent near and far passes', () => {
  assert.match(orbit, /class _ProjectedRingPainter/);
  assert.match(orbit, /front:\s*false/);
  assert.match(orbit, /front:\s*true/);
});

test('orbit supports physical rotation and momentum', () => {
  assert.match(orbit, /_pointerAngle/);
  assert.match(orbit, /onPanStart/);
  assert.match(orbit, /onPanUpdate/);
  assert.match(orbit, /FrictionSimulation/);
  assert.match(orbit, /HapticFeedback\.selectionClick/);
});

test('distance controls visual prominence', () => {
  assert.match(orbit, /node\.perspective/);
  assert.match(orbit, /node\.depth01/);
  assert.match(orbit, /visualScale/);
  assert.match(orbit, /opacity/);
});
