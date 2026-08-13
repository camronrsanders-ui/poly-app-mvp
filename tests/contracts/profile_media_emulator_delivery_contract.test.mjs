import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const backend = fs.readFileSync(
  'functions/src/profile_media.ts',
  'utf8',
);

const client = fs.readFileSync(
  'lib/services/profile_media_service.dart',
  'utf8',
);

const runner = fs.readFileSync(
  'tool/run_ios_local.sh',
  'utf8',
);

test('protected profile photos have a local-emulator delivery path without weakening production delivery', () => {
  assert.match(backend, /runningInFunctionsEmulator\(\)/);
  assert.match(backend, /firebaseStorageDownloadTokens/);
  assert.match(backend, /emulatorOnly:\s*true/);
  assert.match(backend, /getSignedUrl\(\{/);

  assert.match(client, /useFirebaseEmulators/);
  assert.match(
    client,
    /payload\['emulatorHost'\]\s*=\s*firebaseEmulatorHost/,
  );

  assert.doesNotMatch(client, /package:firebase_storage/);
});

test('local emulator state persists between development sessions', () => {
  assert.match(runner, /firebase-emulator-data/);
  assert.match(runner, /--export-on-exit/);
  assert.match(runner, /--import/);
});
