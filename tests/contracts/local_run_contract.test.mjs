import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const preflight = fs.readFileSync(path.join(root, 'tool/dev_preflight.sh'), 'utf8');
const iosRunner = fs.readFileSync(path.join(root, 'tool/run_ios_local.sh'), 'utf8');

test('development preflight checks the runtime versions and app source before simulator testing', () => {
  assert.match(preflight, /Node 22 is required/);
  assert.match(preflight, /Java 21 or newer/);
  assert.match(preflight, /GoogleService-Info\.plist/);
  assert.match(preflight, /com\.mycompany\.polycircle/);
  assert.match(preflight, /flutter analyze lib/);
  assert.match(preflight, /flutter test/);
  assert.match(preflight, /npm --prefix functions run build/);
  assert.match(preflight, /node --test tests\/contracts\/\*\.test\.mjs/);
});

test('one-command iOS runner is pinned to demo Firebase and explicit emulator routing', () => {
  assert.match(iosRunner, /demo-polycircle/);
  assert.match(iosRunner, /--only auth,firestore,functions,storage/);
  assert.match(iosRunner, /USE_FIREBASE_EMULATORS=true/);
  assert.match(iosRunner, /FIREBASE_EMULATOR_HOST=127\.0\.0\.1/);
  assert.doesNotMatch(iosRunner, /poly-circle-j5v6dy/);
});
