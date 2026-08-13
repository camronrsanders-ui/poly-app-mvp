import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const selfProfile = fs.readFileSync(
  path.join(root, 'lib/screens/profile/self_profile_screen.dart'),
  'utf8',
);
const shell = fs.readFileSync(path.join(root, 'lib/screens/main_shell.dart'), 'utf8');

test('owner profile preview renders approved protected photos without public media URLs', () => {
  assert.match(selfProfile, /ProfileMediaService/);
  assert.match(selfProfile, /listMyPhotos\(\)/);
  assert.match(selfProfile, /photo\.status == 'active'/);
  assert.match(selfProfile, /getAccessUrl\(photo\.photoId\)/);
  assert.doesNotMatch(selfProfile, /FirebaseStorage|firebase_storage|photoUrls|avatarUrl/);
});

test('owner profile preview mirrors cross-user public field limits and omits discovery preferences', () => {
  assert.match(selfProfile, /maxLength: 80/);
  assert.match(selfProfile, /maxLength: 1500/);
  assert.match(selfProfile, /maxItems: 12/);
  assert.match(selfProfile, /maxItems: 20/);
  assert.doesNotMatch(selfProfile, /ageMin|ageMax|distanceRadius|preferredStructures|preferredIntentions/);
});

test('owner profile preview has member and connection privacy views for Circle', () => {
  assert.match(selfProfile, /enum _PreviewAudience \{ member, connection \}/);
  assert.match(selfProfile, /mapVisibility == 'private'/);
  assert.match(selfProfile, /visibility == 'matches_only' && !isConnection/);
  assert.match(selfProfile, /visibility == 'unnamed_public'/);
  assert.match(selfProfile, /card\.remove\('displayNameOptional'\)/);
  assert.match(selfProfile, /card\.remove\('note'\)/);
});

test('owner profile preview includes edit and photo-management paths', () => {
  assert.match(selfProfile, /ProfileScreen/);
  assert.match(selfProfile, /ProfilePhotosScreen/);
  assert.match(selfProfile, /View my profile/);
  assert.match(selfProfile, /Circle preview/);
});

test('main shell opens owner preview on Profile tab and refreshes it on re-entry', () => {
  assert.match(shell, /import 'profile\/self_profile_screen\.dart';/);
  assert.match(shell, /4 => const SelfProfileScreen\(\)/);
  assert.match(shell, /index == 1 \|\| index == 3 \|\| index == 4/);
});
