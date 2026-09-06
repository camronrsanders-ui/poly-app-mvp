import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const listing = fs.readFileSync(path.join(root, 'functions/src/profile_media_listing.ts'), 'utf8');
const mediaService = fs.readFileSync(path.join(root, 'lib/services/profile_media_service.dart'), 'utf8');
const profileDetail = fs.readFileSync(path.join(root, 'lib/screens/profile/profile_detail_screen.dart'), 'utf8');

test('remote profile photo listing reuses trusted profile visibility and block checks', () => {
  assert.match(listing, /canViewOwnerProfile/);
  assert.match(listing, /viewingAnotherProfile && !\(await canViewOwnerProfile\(db, uid, ownerUid\)\)/);
  assert.match(listing, /doc\.get\('status'\) === 'active'/);
});

test('remote profile photo listing returns only short-lived signed delivery URLs', () => {
  assert.match(listing, /getSignedUrl/);
  assert.match(listing, /expires:\s*Date\.now\(\) \+ 2 \* 60 \* 1000/);
  assert.match(listing, /expiresInSeconds:\s*120/);
  const viewerBranch = listing.split('if (viewingAnotherProfile)')[1]?.split('const photos = snapshot.docs.map')[0] ?? '';
  assert.doesNotMatch(viewerBranch, /return\s*\{[^}]*storagePath/);
});

test('profile detail requests protected visible photos instead of raw Storage paths', () => {
  assert.match(mediaService, /listVisiblePhotos\(String ownerUid\)/);
  assert.match(mediaService, /httpsCallable\('listMyProfilePhotos'\)/);
  assert.match(
    profileDetail,
    /final profileMedia = ProfileMediaService\(\);/,
  );
  assert.match(
    profileDetail,
    /_loadVisiblePhotos = profileMedia\.listVisiblePhotos;/,
  );
  assert.match(profileDetail, /_loadVisiblePhotos\(_uid\)/);
  assert.match(profileDetail, /Image\.network\(/);
  assert.doesNotMatch(profileDetail, /storagePath/);
});

test('profile photo carousel exposes deliberate position semantics and excludes raw image semantics', () => {
  assert.match(profileDetail, /Semantics\(/);
  assert.match(
    profileDetail,
    /label:\s*'Profile photo \$\{index \+ 1\} of \$\{photos\.length\}'/,
  );
  assert.match(profileDetail, /excludeFromSemantics:\s*true/);
});
