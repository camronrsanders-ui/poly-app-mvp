import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const queue = fs.readFileSync(path.join(root, 'functions/src/profile_media_moderation.ts'), 'utf8');
const review = fs.readFileSync(path.join(root, 'functions/src/profile_media.ts'), 'utf8');
const index = fs.readFileSync(path.join(root, 'functions/src/index.ts'), 'utf8');

test('profile-photo review queue is active-moderator-only, App-Check protected, rate-limited, and bounded', () => {
  assert.match(queue, /moderator.*admin.*superadmin/s);
  assert.match(queue, /enforceAppCheck:\s*true/);
  assert.match(queue, /assertActive\(moderatorUid\)/);
  assert.match(queue, /profile_photo_moderation_list/);
  assert.match(queue, /Math\.min\(Math\.max\(Math\.trunc\(requestedLimit\), 1\), 50\)/);
  assert.match(queue, /where\('status', '==', 'processed_pending_review'\)/);
});

test('moderator preview only signs the trusted processed JPEG path for two minutes', () => {
  assert.match(queue, /users\/\$\{ownerUid\}\/profile\/\$\{photoId\}\.jpg/);
  assert.match(queue, /getSignedUrl/);
  assert.match(queue, /expires:\s*Date\.now\(\) \+ 2 \* 60 \* 1000/);
  assert.match(queue, /expiresInSeconds:\s*120/);
  assert.doesNotMatch(queue, /profile_quarantine/);
});

test('profile-photo moderation queue returns minimal owner metadata and no raw Storage path', () => {
  const returned = queue.match(/return \{photos\};/)?.[0] ?? '';
  assert.ok(returned.length > 0);
  const object = queue.match(/return \{\n\s*photoId:[\s\S]*?\n\s*\};/)?.[0] ?? '';
  assert.match(object, /photoId/);
  assert.match(object, /ownerUid/);
  assert.match(object, /ownerDisplayName/);
  assert.match(object, /previewUrl/);
  assert.doesNotMatch(object, /storagePath|contentType|reviewedByUid|rejectionReason/);
});

test('trusted review callable requires an active privileged reviewer and explicit final state', () => {
  const section = review.match(/export const reviewProfilePhoto = onCall[\s\S]*?export const getProfilePhotoAccess/)?.[0] ?? '';
  assert.match(section, /moderator.*admin.*superadmin/s);
  assert.match(section, /assertActive\(reviewerUid\)/);
  assert.match(section, /processed_pending_review/);
  assert.match(section, /status:\s*'rejected'/);
  assert.match(section, /status:\s*'active'/);
});

test('profile-photo deletion accepts only exact owner quarantine or processed paths', () => {
  assert.match(review, /function requireOwnedProfileMediaPath/);
  assert.match(review, /storagePath === `users\/\$\{ownerUid\}\/profile\/\$\{photoId\}\.jpg`/);
  assert.match(review, /parseQuarantinePath\(storagePath\)/);
  assert.match(review, /requireOwnedProfileMediaPath\(uid, photoId, storagePath\)/);
});

test('profile-photo moderation queue is exported by Functions entrypoint', () => {
  assert.match(index, /listProfilePhotosForReview/);
});
