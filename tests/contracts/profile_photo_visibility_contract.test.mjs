import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const listing = read('functions/src/profile_media_listing.ts');
const access = read('functions/src/profile_access.ts');
const service = read('lib/services/profile_media_service.dart');
const detail = read('lib/screens/profile/profile_detail_screen.dart');

test('remote profile photo listing reuses the trusted profile visibility boundary', () => {
  assert.match(listing, /canViewOwnerProfile/);
  assert.match(listing, /viewingAnotherProfile/);
  assert.match(listing, /permission-denied[\s\S]*Profile photos are unavailable/);
  assert.match(access, /visibility === 'public'/);
  assert.match(access, /visibility === 'matches_only'[\s\S]*hasActiveMatch/);
  assert.match(access, /isBlocked/);
});

test('remote listing exposes approved media only through short-lived signed URLs', () => {
  assert.match(listing, /filter\(\(doc\) => doc\.get\('status'\) === 'active'\)/);
  assert.match(listing, /getSignedUrl/);
  assert.match(listing, /expires:\s*Date\.now\(\) \+ 2 \* 60 \* 1000/);
  assert.match(listing, /expiresInSeconds:\s*120/);
  assert.doesNotMatch(
    listing.match(/if \(viewingAnotherProfile\)[\s\S]*?return \{photos\};/)?.[0] ?? '',
    /storagePath|contentType|reviewedByUid|rejectionReason/,
  );
});

test('Flutter remote profile UI consumes the protected listing instead of raw Storage paths', () => {
  assert.match(service, /listVisiblePhotos\(String ownerUid\)/);
  assert.match(service, /httpsCallable\('listMyProfilePhotos'\)/);
  assert.match(detail, /_profileMedia\.listVisiblePhotos\(_uid\)/);
  assert.match(detail, /Image\.network/);
  assert.doesNotMatch(detail, /FirebaseStorage|storagePath|profile_media/);
});
