import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const circle = fs.readFileSync(
  'lib/screens/circle/my_circle_screen.dart',
  'utf8',
);

const start = circle.indexOf(
  'class _WorldCameraTravel',
);

const end = circle.indexOf(
  'class _SpatialHeader',
  start,
);

const camera = circle.slice(start, end);

test('shared worlds use midpoint camera travel', () => {
  assert.match(circle, /_pendingWorldId/);
  assert.match(circle, /_worldTravelSwapped/);
  assert.match(circle, /_worldTravel\.value < \.5/);
});

test('camera stage uses retained repaint isolation', () => {
  assert.match(camera, /RepaintBoundary/);
});

test('camera uses true perspective and deep Z travel', () => {
  assert.match(camera, /setEntry\(\s*3,\s*2,/);
  assert.match(camera, /translateByDouble/);
  assert.match(camera, /rotateY/);
  assert.match(camera, /scaleByDouble/);
  assert.match(camera, /z = -340/);
});

test('full spatial universe is not faded frame by frame', () => {
  assert.doesNotMatch(camera, /\bOpacity\(/);
});

test('world travel uses responsive timing', () => {
  assert.match(
    circle,
    /Duration\(milliseconds:\s*620\)/,
  );
});

test('arrival retains geometric settle', () => {
  assert.match(camera, /spatialOvershoot/);
  assert.match(
    camera,
    /Curves\.easeOutBack\.transform/,
  );
});

test('world travel retains tactile feedback', () => {
  assert.match(
    circle,
    /HapticFeedback\.lightImpact/,
  );
  assert.match(
    circle,
    /HapticFeedback\.selectionClick/,
  );
});
