const test = require('node:test');
const assert = require('node:assert/strict');
const {
  coordinateIsWithinRadius,
  defaultDiscoveryRadiusMiles,
  distanceMiles,
  normalizeDiscoveryRadius,
  parseDiscoverLocationUpdate,
  privateCoordinateFromData,
} = require('../lib/discovery_location.js');

const origin = {latitude: 12.3456, longitude: -45.6789};

function pointApproximatelyMilesEast(miles) {
  const milesPerLongitudeDegree = 69.172
    * Math.cos(origin.latitude * Math.PI / 180);
  return {
    latitude: origin.latitude,
    longitude: origin.longitude + miles / milesPerLongitudeDegree,
  };
}

test('missing and unsupported preferences normalize to the 20-mile default', () => {
  assert.equal(defaultDiscoveryRadiusMiles, 20);
  assert.equal(normalizeDiscoveryRadius(undefined), 20);
  assert.equal(normalizeDiscoveryRadius(25), 20);
  assert.equal(normalizeDiscoveryRadius(50), 50);
});

test('a candidate inside five miles is included and one outside is excluded', () => {
  assert.equal(coordinateIsWithinRadius(origin, pointApproximatelyMilesEast(4.9), 5), true);
  assert.equal(coordinateIsWithinRadius(origin, pointApproximatelyMilesEast(5.1), 5), false);
});

test('increasing the selected radius makes the same farther candidate eligible', () => {
  const candidate = pointApproximatelyMilesEast(7);
  assert.equal(coordinateIsWithinRadius(origin, candidate, 5), false);
  assert.equal(coordinateIsWithinRadius(origin, candidate, 10), true);
});

test('the exact computed boundary is inclusive', () => {
  const candidate = pointApproximatelyMilesEast(10);
  const boundary = distanceMiles(origin, candidate);
  assert.equal(coordinateIsWithinRadius(origin, candidate, boundary), true);
  assert.equal(coordinateIsWithinRadius(origin, candidate, boundary - 0.000001), false);
});

test('missing and invalid private coordinates fail closed', () => {
  assert.equal(privateCoordinateFromData(undefined), null);
  assert.equal(privateCoordinateFromData({latitude: 91, longitude: 0}), null);
  assert.equal(privateCoordinateFromData({latitude: 0, longitude: -181}), null);
  assert.equal(privateCoordinateFromData({latitude: 'bad', longitude: 0}), null);
  assert.deepEqual(privateCoordinateFromData(origin), origin);
});

test('foreground location updates reject stale, future, inaccurate, and invalid data', () => {
  const now = 1_800_000_000_000;
  const valid = {
    ...origin,
    accuracyMeters: 250,
    observedAtMs: now - 1000,
  };
  assert.deepEqual(parseDiscoverLocationUpdate(valid, now), valid);
  assert.equal(parseDiscoverLocationUpdate({...valid, latitude: 100}, now), null);
  assert.equal(parseDiscoverLocationUpdate({...valid, accuracyMeters: 50_001}, now), null);
  assert.equal(parseDiscoverLocationUpdate({...valid, observedAtMs: now - 86_400_001}, now), null);
  assert.equal(parseDiscoverLocationUpdate({...valid, observedAtMs: now + 300_001}, now), null);
});
