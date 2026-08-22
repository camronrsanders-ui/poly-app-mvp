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
const androidBuild = fs.readFileSync('android/app/build.gradle.kts', 'utf8');
const iosInfo = fs.readFileSync('ios/Runner/Info.plist', 'utf8');
const iosProject = fs.readFileSync(
  'ios/Runner.xcodeproj/project.pbxproj',
  'utf8',
);
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

test('Android and iOS use the same permanent Polycircle app identity', () => {
  assert.ok(androidBuild.includes('namespace = "com.polycircle.app"'));
  assert.ok(androidBuild.includes('applicationId = "com.polycircle.app"'));
  assert.ok(iosProject.includes('PRODUCT_BUNDLE_IDENTIFIER = com.polycircle.app;'));
  assert.ok(androidManifest.includes('android:label="Polycircle"'));
  assert.ok(iosInfo.includes('<string>Polycircle</string>'));
});

test('Android and iOS expose the same Flutter native bridge surface', () => {
  for (const token of sharedBridgeTokens) {
    assert.ok(androidHost.includes(token), `Android native host missing ${token}`);
    assert.ok(iosHost.includes(token), `iOS native host missing ${token}`);
  }
});

test('Android and iOS keep Discover one-shot location payloads compatible', () => {
  for (const token of sharedLocationPayloadTokens) {
    assert.ok(androidHost.includes(token), `Android location bridge missing ${token}`);
    assert.ok(iosHost.includes(token), `iOS location bridge missing ${token}`);
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
