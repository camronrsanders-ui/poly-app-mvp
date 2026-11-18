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
const screen = fs.readFileSync(path.join(root, 'lib/screens/safety/profile_photo_moderation_screen.dart'), 'utf8');
const opsScript = fs.readFileSync(path.join(root, 'functions/scripts/set_moderator_claim.cjs'), 'utf8');

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

test('moderator UI is claim-gated in every build flavor; the QA double gate is deliberately reversed', () => {
  // Photo uploads PR 3 (adopted Decision 2a): this test used to pin
  // the opposite policy — a debug-mode + emulator-routing double
  // gate that kept the moderation UI local-QA-only. That pin is
  // reversed on purpose. Photo moderation is now a production staff
  // surface whose only client gate is the moderator claim the
  // callables re-check server-side; the emulator QA path keeps
  // working because the seeded local moderator holds that claim.
  assert.match(client, /hasModeratorAccess/);
  assert.match(safety, /hasModeratorAccess/);
  assert.doesNotMatch(client, /hasLocalModeratorAccess/);
  assert.doesNotMatch(safety, /hasLocalModeratorAccess/);
  assert.doesNotMatch(client, /!kDebugMode \|\| !useFirebaseEmulators/);
  assert.doesNotMatch(safety, /!kDebugMode \|\| !useFirebaseEmulators/);
  assert.doesNotMatch(safety, /Local moderator QA/);
  assert.match(safety, /Photo moderation/);
  assert.match(client, /claims\['moderator'\] == true/);
  assert.match(client, /claims\['admin'\] == true/);
  assert.match(client, /claims\['superadmin'\] == true/);
  assert.match(client, /listProfilePhotosForReview/);
  assert.match(client, /reviewProfilePhoto/);
});

test('production moderation surface uses the adopted reason taxonomy and a guarded claim script', () => {
  // The reject flow picks from the fixed taxonomy PR 2 shipped
  // (adopted Decision 5) instead of sending the QA-era hard-coded
  // string, and the screen carries production copy throughout.
  assert.match(screen, /Photo moderation/);
  assert.doesNotMatch(screen, /Local photo moderation/);
  assert.doesNotMatch(screen, /local_moderation_qa/);
  assert.doesNotMatch(screen, /emulator-only/);
  for (const code of ['community_guidelines', 'image_quality', 'other_policy']) {
    assert.match(screen, new RegExp(code), `picker code ${code} missing`);
  }
  // Claim operations are explicit and guarded: project and uid are
  // required arguments, and the write needs a deliberate --confirm.
  assert.match(opsScript, /--project/);
  assert.match(opsScript, /--uid/);
  assert.match(opsScript, /--grant/);
  assert.match(opsScript, /--revoke/);
  assert.match(opsScript, /--confirm/);
  assert.match(opsScript, /setCustomUserClaims/);
  assert.match(opsScript, /Refusing to change moderator claims/);
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
