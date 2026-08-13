import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const runner = fs.readFileSync(path.join(root, 'tool/run_android_local.sh'), 'utf8');

test('Android local runner resolves an actual Android Flutter device', () => {
  assert.match(runner, /flutter devices --machine/);
  assert.match(runner, /targetPlatform \|\| ""\)\.startsWith\("android"\)/);
  assert.match(runner, /String\(device\.id \|\| ""\)\.toLowerCase\(\) === request/);
  assert.match(runner, /String\(device\.name \|\| ""\)\.toLowerCase\(\) === request/);
  assert.match(runner, /flutter run -d \\"\$DEVICE_ID\\"/);
});

test('Android local runner has no brittle display-name default', () => {
  assert.match(runner, /DEVICE_REQUEST="\$\{1:-\}"/);
  assert.doesNotMatch(runner, /DEVICE="\$\{1:-Android Emulator\}"/);
  assert.doesNotMatch(runner, /flutter devices \| grep -Fq/);
});

test('Android local runner keeps emulator routing and project guards intact', () => {
  assert.match(runner, /FIREBASE_PROJECT_ID="poly-circle-j5v6dy"/);
  assert.match(runner, /ANDROID_HOST="\$\{POLYCIRCLE_ANDROID_FIREBASE_HOST:-10\.0\.2\.2\}"/);
  assert.match(runner, /POLYCIRCLE_ALLOW_REAL_PROJECT_EMULATOR=true/);
  assert.match(runner, /FIREBASE_EMULATOR_HOST=\$ANDROID_HOST/);
  assert.match(runner, /if \[\[ ! -d android \]\]/);
  assert.match(runner, /android\/app\/google-services\.json/);
});
