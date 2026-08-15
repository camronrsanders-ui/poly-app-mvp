import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const circle = fs.readFileSync(
  'lib/screens/circle/my_circle_screen.dart',
  'utf8',
);

test('My Circle uses the spatial relationship universe', () => {
  assert.match(circle, /PolycircleSpatialOrbit/);
  assert.match(circle, /MY CIRCLE/);
  assert.match(circle, /Your relationship universe/);
});

test('My Circle is centered on the signed-in member', () => {
  assert.match(circle, /class _OwnerWorld/);
  assert.match(circle, /photoFuture/);
  assert.match(circle, /'YOU'/);
});

test('My Circle loads trusted connections and protected photos', () => {
  assert.match(circle, /ConnectionService/);
  assert.match(circle, /ProfileMediaService/);
  assert.match(circle, /listVisiblePhotos/);
});

test('focused connection opens the trusted profile view', () => {
  assert.match(circle, /ProfileDetailScreen/);
  assert.match(circle, /showConnectAction:\s*false/);
});

test('legacy relationship management remains reachable', () => {
  assert.match(circle, /RelationshipManagerScreen/);
  assert.match(circle, /Manage relationships/);
});

test('My Circle includes a spatial glass detail layer', () => {
  assert.match(circle, /BackdropFilter/);
  assert.match(circle, /ImageFilter\.blur/);
  assert.match(circle, /_SpatialBackground/);
});
