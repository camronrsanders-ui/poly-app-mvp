import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const preflight = fs.readFileSync(path.join(root, 'tool/dev_preflight.sh'), 'utf8');
const iosRunner = fs.readFileSync(path.join(root, 'tool/run_ios_local.sh'), 'utf8');
const iosRepair = fs.readFileSync(path.join(root, 'tool/ensure_ios_runtime.sh'), 'utf8');

test('development preflight checks the runtime versions and app source before simulator testing', () => {
  assert.match(preflight, /Node 22 is required/);
  assert.match(preflight, /Java 21 or newer/);
  assert.match(preflight, /GoogleService-Info\.plist/);
  assert.match(preflight, /com\.mycompany\.polycircle/);
  assert.match(preflight, /flutter analyze lib/);
  assert.match(preflight, /flutter test/);
  assert.match(preflight, /npm --prefix functions install/);
  assert.match(preflight, /npm --prefix functions run build/);
  assert.match(preflight, /npm --prefix functions test/);
  assert.match(preflight, /node --test tests\/contracts\/\*\.test\.mjs/);
});

test('one-command iOS runner matches the native Firebase project while routing every used backend service locally', () => {
  assert.match(iosRunner, /FIREBASE_PROJECT_ID="poly-circle-j5v6dy"/);
  assert.match(iosRunner, /--project "\$FIREBASE_PROJECT_ID"/);
  assert.match(iosRunner, /--only auth,firestore,functions,storage/);
  assert.match(iosRunner, /USE_FIREBASE_EMULATORS=true/);
  assert.match(iosRunner, /FIREBASE_EMULATOR_HOST=127\.0\.0\.1/);
  assert.match(iosRunner, /POLYCIRCLE_ALLOW_REAL_PROJECT_EMULATOR=true/);
  assert.doesNotMatch(iosRunner, /firebase deploy/);
});

test('one-command iOS runner detects common local setup collisions before Firebase starts', () => {
  assert.match(iosRunner, /restart-foundation/);
  assert.match(iosRunner, /lsof/);
  for (const port of ['4000', '5001', '8080', '9099', '9199']) {
    assert.match(iosRunner, new RegExp(port));
  }
  assert.match(iosRunner, /Close the old emulator\/process first/);
});

test('one-command iOS runner refreshes approved branding when the source artwork is available', () => {
  assert.match(iosRunner, /install_branding\.sh --if-present/);
});

test('one-command iOS runner repairs an incomplete or stale native iOS shell before validation', () => {
  assert.match(iosRunner, /ensure_ios_runtime\.sh/);
  assert.match(iosRepair, /flutter create --platforms=ios \./);
  assert.match(iosRepair, /GoogleService-Info\.plist/);
  assert.match(iosRepair, /IPHONEOS_DEPLOYMENT_TARGET/);
  assert.match(iosRepair, /15\.0/);
  assert.match(iosRepair, /preserved GoogleService-Info\.plist/);
});
