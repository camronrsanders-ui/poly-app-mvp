import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const screen = read('lib/screens/profile/profile_photos_screen.dart');
const profileScreen = read('lib/screens/profile/profile_screen.dart');
const service = read('lib/services/profile_media_service.dart');

test('profile photo management uses the trusted media service instead of direct Firebase storage', () => {
  assert.match(screen, /ProfileMediaService/);
  assert.doesNotMatch(screen, /firebase_storage|FirebaseStorage/);
  assert.doesNotMatch(screen, /cloud_firestore|FirebaseFirestore/);
  for (const method of ['beginUpload', 'uploadBytes', 'confirmUpload', 'listMyPhotos', 'getAccessUrl', 'deletePhoto']) {
    assert.match(screen, new RegExp(`_service\\.${method}\\(`), `${method} is not used by the profile-photo UI`);
  }
});

test('profile photo UI cannot call moderator review operations', () => {
  assert.doesNotMatch(screen, /reviewProfilePhoto|reviewProfileMedia|moderator|admin claim/i);
  assert.doesNotMatch(service, /httpsCallable\(['"]reviewProfilePhoto['"]\)/);
});

test('owner profile exposes protected photo management without storing media URLs in profile fields', () => {
  assert.match(profileScreen, /ProfilePhotosScreen/);
  assert.match(profileScreen, /Manage profile photos/);
  assert.doesNotMatch(profileScreen, /photoUrls|avatarUrl|storagePath|uploadUrl/);
});

test('active-photo preview requests a fresh protected access URL on demand', () => {
  assert.match(screen, /photo\.status != 'active'/);
  assert.match(screen, /_getAccessUrl\(photo\.photoId\)/);
  assert.doesNotMatch(screen, /SharedPreferences|secure_storage|writeAsString|photoUrls/);
});


test('profile photo production binding stays lazy and duplicate deletion is guarded', () => {
  assert.match(screen, /ProfileMediaService\? _serviceInstance/);
  assert.match(
    screen,
    /ProfileMediaService get _service[\s\S]{0,180}ProfileMediaService\(\)/,
  );
  assert.match(
    screen,
    /return _service\.listMyPhotos\(\)/,
  );
  assert.match(
    screen,
    /return _service\.getAccessUrl\(photoId\)/,
  );
  assert.match(
    screen,
    /return _service\.deletePhoto\(photoId\)/,
  );
  assert.match(
    screen,
    /final Set<String> _deletingPhotoIds = <String>\{\}/,
  );
  assert.match(
    screen,
    /if \(_deletingPhotoIds\.contains\(photo\.photoId\)\) return/,
  );
  assert.match(
    screen,
    /enabled:\s*!_deletingPhotoIds\.contains\(photo\.photoId\)/,
  );
});
