import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const review = fs.readFileSync(path.join(root, 'functions/src/profile_media.ts'), 'utf8');
const queue = fs.readFileSync(path.join(root, 'functions/src/profile_media_moderation.ts'), 'utf8');
const seed = fs.readFileSync(path.join(root, 'functions/scripts/seed_emulator.cjs'), 'utf8');
const client = fs.readFileSync(path.join(root, 'lib/services/profile_photo_moderation_service.dart'), 'utf8');
const safety = fs.readFileSync(path.join(root, 'lib/screens/safety/safety_center_screen.dart'), 'utf8');

test('profile photo reviewers cannot approve or reject their own media', () => {
  const section = review.match(/export const reviewProfilePhoto = onCall[\s\S]*?export const getProfilePhotoAccess/)?.[0] ?? '';
  assert.match(section, /ownerUid === reviewerUid/);
  assert.match(section, /Reviewers cannot review their own profile photos/);
  assert.match(section, /permission-denied/);
});

test('local seed creates a hidden least-privilege moderator and clears stale claims', () => {
  assert.match(seed, /uid: 'local-moderator'/);
  assert.match(seed, /email: 'moderator@local\.polycircle\.test'/);
  assert.match(seed, /authClaims: \{moderator: true\}/);
  assert.match(seed, /profileVisibility: 'hidden'/);
  assert.match(seed, /openToConnections: false/);
  assert.match(seed, /setCustomUserClaims\(person\.uid, person\.authClaims \?\? \{\}\)/);
  assert.match(seed, /authClaims: _authClaims/);
});

test('local moderator UI is double-gated by debug mode, emulator routing, and auth claim', () => {
  assert.match(safety, /!kDebugMode \|\| !useFirebaseEmulators/);
  assert.match(safety, /hasLocalModeratorAccess/);
  assert.match(client, /!kDebugMode \|\| !useFirebaseEmulators/);
  assert.match(client, /claims\['moderator'\] == true/);
  assert.match(client, /claims\['admin'\] == true/);
  assert.match(client, /claims\['superadmin'\] == true/);
  assert.match(client, /listProfilePhotosForReview/);
  assert.match(client, /reviewProfilePhoto/);
});

test('emulator moderation preview stays trusted while production keeps short-lived signed delivery', () => {
  assert.match(queue, /FUNCTIONS_EMULATOR === 'true'/);
  assert.match(queue, /previewBytesBase64/);
  assert.match(queue, /maxLocalPreviewBytes/);
  assert.match(queue, /resize\(\{width: 900, height: 900/);
  assert.match(queue, /getSignedUrl/);
  assert.match(queue, /expires: Date\.now\(\) \+ 2 \* 60 \* 1000/);
  assert.doesNotMatch(client, /firebase_storage|FirebaseStorage/);
});
