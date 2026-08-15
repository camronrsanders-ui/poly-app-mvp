import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const circle = fs.readFileSync(
  'lib/screens/circle/my_circle_screen.dart',
  'utf8',
);

const shell = fs.readFileSync(
  'lib/screens/main_shell.dart',
  'utf8',
);

test('My Circle owns an immersive spatial canvas', () => {
  assert.match(circle, /PolycircleSpatialOrbit/);
  assert.match(circle, /_SpatialBackground/);
  assert.match(circle, /BackdropFilter/);
  assert.match(circle, /ImageFilter\.blur/);
});

test('My Circle has spatial world switching', () => {
  assert.match(circle, /class _WorldDock/);
  assert.match(circle, /AnimatedSwitcher/);
  assert.match(circle, /ScaleTransition/);
  assert.match(circle, /FadeTransition/);
});

test('shared world previews are emulator-only', () => {
  assert.match(circle, /kDebugMode/);
  assert.match(circle, /useFirebaseEmulators/);
  assert.match(circle, /Chosen Family/);
  assert.match(circle, /House/);
});

test('My Circle keeps safety and relationship management reachable', () => {
  assert.match(circle, /SafetyCenterScreen/);
  assert.match(circle, /RelationshipManagerScreen/);
});

test('My Circle uses protected profile photos', () => {
  assert.match(circle, /ProfileMediaService/);
  assert.match(circle, /listVisiblePhotos/);
});

test('MainShell gives Circle the full canvas', () => {
  assert.match(shell, /2\s*=>\s*const MyCircleScreen/);
  assert.match(shell, /_index\s*==\s*2[\s\S]*\?\s*null/);
});
