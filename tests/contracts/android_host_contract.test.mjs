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

test('Android host uses permanent Polycircle application identity', () => {
  assert.match(appGradle, /namespace\s*=\s*"com\.polycircle\.app"/);
  assert.match(appGradle, /applicationId\s*=\s*"com\.polycircle\.app"/);
  assert.doesNotMatch(appGradle, /com\.example\.polycircle/);
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
