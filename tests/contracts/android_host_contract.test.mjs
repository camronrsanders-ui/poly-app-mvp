import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const appGradle = fs.readFileSync(
  'android/app/build.gradle.kts',
  'utf8',
);

const settings = fs.readFileSync(
  'android/settings.gradle.kts',
  'utf8',
);

const runner = fs.readFileSync(
  'tool/run_android_local.sh',
  'utf8',
);

const preflight = fs.readFileSync(
  'tool/dev_preflight.sh',
  'utf8',
);

test('Android host uses permanent Polycircle application identity', () => {
  assert.match(appGradle, /namespace\s*=\s*"com\.polycircle\.app"/);
  assert.match(appGradle, /applicationId\s*=\s*"com\.polycircle\.app"/);
  assert.match(appGradle, /flavorDimensions \+= "environment"/);
  assert.match(appGradle, /resValues\s*=\s*true/);
  assert.match(appGradle, /create\("production"\)/);
  assert.match(appGradle, /create\("staging"\)/);
  assert.match(appGradle, /applicationIdSuffix = "\.staging"/);
  assert.match(appGradle, /resValue\("string", "app_name", "Polycircle"\)/);
  assert.match(
    appGradle,
    /resValue\("string", "app_name", "Polycircle Staging"\)/,
  );
  assert.doesNotMatch(appGradle, /com\.example\.polycircle/);
});

test('Android release signing fails closed and never falls back to debug keys', () => {
  for (const name of [
    'POLYCIRCLE_ANDROID_KEYSTORE_PATH',
    'POLYCIRCLE_ANDROID_KEYSTORE_PASSWORD',
    'POLYCIRCLE_ANDROID_KEY_ALIAS',
    'POLYCIRCLE_ANDROID_KEY_PASSWORD',
  ]) {
    assert.match(appGradle, new RegExp(name));
  }

  assert.match(
    appGradle,
    /val hasCompleteReleaseSigning = releaseSigningValues\.all \{ it != null \}/,
  );
  assert.match(
    appGradle,
    /signingConfigs\s*\{[\s\S]*create\("release"\)/,
  );
  assert.match(
    appGradle,
    /signingConfig = if \(hasCompleteReleaseSigning\)/,
  );
  assert.match(appGradle, /verifyReleaseSigning/);
  assert.match(appGradle, /it\.name\.startsWith\("pre"\)/);
  assert.match(appGradle, /it\.name\.endsWith\("ReleaseBuild"\)/);
  assert.match(appGradle, /dependsOn\(verifyReleaseSigning\)/);
  assert.match(appGradle, /throw GradleException/);

  assert.doesNotMatch(
    appGradle,
    /signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)/,
  );
  assert.doesNotMatch(appGradle, /storePassword\s*=\s*"/);
  assert.doesNotMatch(appGradle, /keyPassword\s*=\s*"/);
  assert.doesNotMatch(appGradle, /keyAlias\s*=\s*"/);
  assert.doesNotMatch(appGradle, /storeFile\s*=\s*file\("/);
});

test('Android Firebase configuration is wired through Google Services', () => {
  assert.match(
    settings,
    /com\.google\.gms\.google-services/,
  );
  assert.match(
    appGradle,
    /com\.google\.gms\.google-services/,
  );
});

test('Android local runner is emulator-only and preserves local state', () => {
  assert.match(runner, /ensure_node22\.sh/);
  assert.match(runner, /ensure_java21\.sh/);
  assert.match(runner, /firebase-emulator-data/);
  assert.match(runner, /--import=/);
  assert.match(runner, /--export-on-exit=/);
  assert.match(runner, /USE_FIREBASE_EMULATORS=true/);
  assert.match(runner, /FIREBASE_EMULATOR_HOST=\$ANDROID_HOST/);
  assert.match(runner, /auth,firestore,functions,storage/);
  assert.match(runner, /google-services\.json/);
});


test('Android Firebase preflight is explicit and environment-aware', () => {
  assert.match(preflight, /ENVIRONMENT="\$\{1:-\}"/);
  assert.match(preflight, /production\|staging/);
  assert.match(preflight, /poly-circle-j5v6dy/);
  assert.match(preflight, /polycircle-staging-82204f/);
  assert.match(preflight, /com\.polycircle\.app"/);
  assert.match(preflight, /com\.polycircle\.app\.staging"/);
  assert.match(
    preflight,
    /android\/app\/src\/production\/google-services\.json/,
  );
  assert.match(
    preflight,
    /android\/app\/src\/staging\/google-services\.json/,
  );
  assert.match(preflight, /ANDROID_MATCHING_APP_ID/);
  assert.match(preflight, /package_name === expected/);
  assert.match(preflight, /EXPECTED_ANDROID_APP_ID/);
  assert.doesNotMatch(preflight, /names\[0\]/);
});
