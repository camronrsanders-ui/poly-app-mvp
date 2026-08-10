import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const queue = fs.readFileSync(path.join(root, 'functions/src/profile_media_moderation.ts'), 'utf8');
const review = fs.readFileSync(path.join(root, 'functions/src/profile_media.ts'), 'utf8');
const index = fs.readFileSync(path.join(root, 'functions/src/index.ts'), 'utf8');

test('profile-photo review queue is moderator-only, App-Check protected, rate-limited, and bounded', () => {
  assert.match(queue, /moderator.*admin.*superadmin/s);
  assert.match(queue, /enforceAppCheck:\s*true/);
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

test('existing trusted review callable performs final moderation state transition', () => {
  assert.match(review, /export const reviewProfilePhoto = onCall/);
  assert.match(review, /moderator.*admin/s);
  assert.match(review, /processed_pending_review/);
  assert.match(review, /status:\s*approve \? 'active' : 'rejected'/);
});

test('profile-photo moderation queue is exported by Functions entrypoint', () => {
  assert.match(index, /listProfilePhotosForReview/);
});
