import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const listing = fs.readFileSync(
  'functions/src/profile_media_listing.ts',
  'utf8',
);

const service = fs.readFileSync(
  'lib/services/profile_media_service.dart',
  'utf8',
);

test('cross-user profile-photo listing keeps production signed delivery', () => {
  assert.match(listing, /getSignedUrl/);
  assert.match(listing, /expiresInSeconds: 120/);
});

test('cross-user profile-photo listing has emulator-only download delivery', () => {
  assert.match(listing, /runningInFunctionsEmulator/);
  assert.match(listing, /firebaseStorageDownloadTokens/);
  assert.match(listing, /10\.0\.2\.2/);
  assert.match(listing, /expiresInSeconds: 0/);
});

test('Flutter sends the guarded emulator host when listing visible photos', () => {
  assert.match(service, /useFirebaseEmulators/);
  assert.match(
    service,
    /payload\['emulatorHost'\] = firebaseEmulatorHost/,
  );
});
