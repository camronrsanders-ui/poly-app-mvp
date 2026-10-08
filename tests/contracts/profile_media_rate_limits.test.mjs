import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const index = read('functions/src/index.ts');
const profileMedia = read('functions/src/profile_media.ts');
const profileMediaListing = read('functions/src/profile_media_listing.ts');

const expectedActions = [
  'profile_photo_upload',
  'profile_photo_confirm',
  'profile_photo_review',
  'profile_photo_access',
  'profile_photo_delete',
  'profile_photo_list',
];

test('every client-reachable profile-media operation has an abuse budget', () => {
  for (const action of expectedActions.slice(0, -1)) {
    assert.match(
      profileMedia,
      new RegExp(`['\"]${action}['\"]`),
      `Missing profile-media rate limit action ${action}`,
    );
  }
  assert.match(profileMediaListing, /action\s*=\s*['"]profile_photo_list['"]/);
});

test('profile-media rate limits are backend-only and removed during account deletion', () => {
  for (const action of expectedActions) {
    assert.match(
      index,
      new RegExp(`['\"]${action}['\"]`),
      `Account deletion does not clean rate-limit state ${action}`,
    );
  }
});

test('protected profile-photo delivery uses a short-lived signed URL and a per-minute budget', () => {
  assert.match(profileMedia, /getProfilePhotoAccess[\s\S]*profile_photo_access/);
  assert.match(profileMedia, /expires:\s*Date\.now\(\)\s*\+\s*2\s*\*\s*60\s*\*\s*1000/);
  assert.match(profileMedia, /profile_photo_access['"],\s*120,\s*60_000/);
});
