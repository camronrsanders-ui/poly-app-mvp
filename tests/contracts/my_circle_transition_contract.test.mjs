import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const circle = fs.readFileSync(
  'lib/screens/circle/my_circle_screen.dart',
  'utf8',
);

test('shared worlds use two-phase camera travel', () => {
  assert.match(circle, /class _WorldCameraTravel/);
  assert.match(circle, /_pendingWorldId/);
  assert.match(circle, /_worldTravelSwapped/);
  assert.match(circle, /_worldTravel\.value < \.5/);
});

test('world swaps while distant from camera', () => {
  assert.match(
    circle,
    /_activeWorldId = _pendingWorldId!/,
  );
});

test('camera movement contains true Z-depth', () => {
  assert.match(circle, /setEntry\(3,\s*2,/);
  assert.match(circle, /translateByDouble/);
  assert.match(circle, /rotateY/);
  assert.match(circle, /scaleByDouble/);
  assert.match(circle, /z = -175/);
});

test('overshoot affects geometry rather than opacity', () => {
  assert.match(
    circle,
    /spatialOvershoot/,
  );

  assert.match(
    circle,
    /Curves\.easeOutBack\.transform/,
  );

  assert.match(
    circle,
    /opacity = \(\.10 \+ \(\.90 \* movement\)\)/,
  );
});

test('world travel includes tactile feedback', () => {
  assert.match(
    circle,
    /HapticFeedback\.lightImpact/,
  );

  assert.match(
    circle,
    /HapticFeedback\.selectionClick/,
  );
});
