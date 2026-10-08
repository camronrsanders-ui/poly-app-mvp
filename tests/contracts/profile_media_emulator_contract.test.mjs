import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const backend = fs.readFileSync(path.join(root, 'functions/src/profile_media.ts'), 'utf8');
const client = fs.readFileSync(path.join(root, 'lib/services/profile_media_service.dart'), 'utf8');
const storageRules = fs.readFileSync(path.join(root, 'storage.rules'), 'utf8');

test('local profile photo upload avoids signed URLs only inside the Functions emulator', () => {
  assert.match(backend, /process\.env\.FUNCTIONS_EMULATOR === 'true'/);
  assert.match(backend, /uploadTransport = 'emulator_confirm_callable'/);
  assert.match(backend, /getSignedUrl\(\{[\s\S]*?version: 'v4'[\s\S]*?action: 'write'/);
});

test('emulator photo bytes are accepted only by the trusted confirm callable', () => {
  assert.match(backend, /const emulatorBytes = request\.data\?\.emulatorBytesBase64/);
  assert.match(backend, /if \(!runningInFunctionsEmulator\(\)\)[\s\S]*?permission-denied/);
  assert.match(backend, /requireEmulatorUploadBytes\(emulatorBytes\)/);
  assert.match(backend, /getStorage\(\)\.bucket\(\)\.file\(storagePath\)\.save\(bytes/);
});

test('Flutter accepts the emulator transport only in explicit emulator builds', () => {
  assert.match(client, /uploadTransport == 'emulator_confirm_callable'/);
  assert.match(client, /!useFirebaseEmulators/);
  assert.match(client, /httpsCallable\('confirmProfilePhotoUpload'\)/);
  assert.match(client, /emulatorBytesBase64/);
  assert.match(client, /base64Encode\(bytes\)/);
});

test('profile Storage remains default-deny despite local QA transport', () => {
  assert.match(storageRules, /allow read, write: if false/);
  assert.doesNotMatch(storageRules, /FUNCTIONS_EMULATOR|emulator_confirm_callable/);
});
