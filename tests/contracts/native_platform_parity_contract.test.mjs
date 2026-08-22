import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const androidHost = fs.readFileSync(
  'android/app/src/main/kotlin/com/polycircle/app/MainActivity.kt',
  'utf8',
);
const iosHost = fs.readFileSync('ios/Runner/AppDelegate.swift', 'utf8');
const androidManifest = fs.readFileSync(
  'android/app/src/main/AndroidManifest.xml',
  'utf8',
);
const iosInfo = fs.readFileSync('ios/Runner/Info.plist', 'utf8');
const androidRunner = fs.readFileSync('tool/run_android_local.sh', 'utf8');
const iosRunner = fs.readFileSync('tool/run_ios_local.sh', 'utf8');

const sharedBridgeTokens = [
  'com.polycircle.app/age_assurance',
  'com.polycircle.app/discover_location',
  'requestAdultAgeSignal',
  'requestCurrentLocation',
  'openLocationSettings',
];

const sharedLocationPayloadTokens = [
  'LOCATION_REQUEST_IN_PROGRESS',
  'services_disabled',
  'denied',
  'unavailable',
  'ready',
  'latitude',
  'longitude',
  'accuracyMeters',
  'observedAtMs',
];

test('Android and iOS expose the same Flutter native bridge surface', () => {
  for (const token of sharedBridgeTokens) {
    assert.match(androidHost, new RegExp(token.replaceAll('/', '\\/')));
    assert.match(iosHost, new RegExp(token.replaceAll('/', '\\/')));
  }
});

test('Android and iOS keep Discover one-shot location payloads compatible', () => {
  for (const token of sharedLocationPayloadTokens) {
    assert.match(androidHost, new RegExp(token));
    assert.match(iosHost, new RegExp(token));
  }
});

test('location permissions remain foreground-only on both platforms', () => {
  assert.match(androidManifest, /ACCESS_COARSE_LOCATION/);
  assert.match(androidManifest, /ACCESS_FINE_LOCATION/);
  assert.doesNotMatch(androidManifest, /ACCESS_BACKGROUND_LOCATION/);

  assert.match(iosInfo, /NSLocationWhenInUseUsageDescription/);
  assert.doesNotMatch(iosInfo, /NSLocationAlwaysUsageDescription/);
  assert.doesNotMatch(iosInfo, /NSLocationAlwaysAndWhenInUseUsageDescription/);
});

test('Android and iOS local launchers target the same guarded Firebase emulator stack', () => {
  for (const runner of [androidRunner, iosRunner]) {
    assert.match(runner, /FIREBASE_PROJECT_ID="poly-circle-j5v6dy"/);
    assert.match(runner, /POLYCIRCLE_DISCOVER_FIXTURE_COUNT/);
    assert.match(runner, /POLYCIRCLE_DISCOVER_FIXTURE_RADIUS/);
    assert.match(runner, /--only auth,firestore,functions,storage/);
    assert.match(runner, /--dart-define=USE_FIREBASE_EMULATORS=true/);
    assert.match(runner, /12\.3456/);
    assert.match(runner, /-45\.6789/);
  }
});

test('adult-only age assurance remains fail-closed on both native hosts', () => {
  for (const host of [androidHost, iosHost]) {
    assert.match(host, /"status"/);
    assert.match(host, /"adult"/);
    assert.match(host, /"minor"/);
    assert.match(host, /"unavailable"/);
    assert.match(host, /"regulatedRegion"/);
  }
});
