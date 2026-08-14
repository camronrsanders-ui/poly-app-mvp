import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const runtime = fs.readFileSync(
  path.join(root, 'lib/config/firebase_runtime.dart'),
  'utf8',
);
const main = fs.readFileSync(path.join(root, 'lib/main.dart'), 'utf8');

test('normal release builds cannot silently enable Firebase emulators', () => {
  assert.match(runtime, /POLYCIRCLE_LOCAL_RELEASE_SMOKE/);
  assert.match(runtime, /if \(!kDebugMode && !localReleaseSmoke\)/);
  assert.match(runtime, /Release emulator routing requires/);
  assert.match(runtime, /if \(!useFirebaseEmulators\)/);
});

test('explicit local release smoke routes trusted Firebase services locally', () => {
  assert.match(runtime, /useAuthEmulator\(firebaseEmulatorHost, 9099\)/);
  assert.match(runtime, /useFirestoreEmulator\(firebaseEmulatorHost, 8080\)/);
  assert.match(runtime, /useFunctionsEmulator\(firebaseEmulatorHost, 5001\)/);
});

test('Android local release smoke uses debug App Check without changing normal release', () => {
  assert.match(main, /localReleaseSmoke && useFirebaseEmulators/);
  assert.match(main, /kDebugMode \|\| localSmokeAppCheck/);
  assert.match(main, /AndroidDebugProvider/);
  assert.match(main, /AndroidPlayIntegrityProvider/);
});


test('Android release smoke permits emulator cleartext only with an explicit host build flag', () => {
  const gradle = fs.readFileSync(
    path.join(root, 'android/app/build.gradle.kts'),
    'utf8',
  );
  const manifest = fs.readFileSync(
    path.join(root, 'android/app/src/main/AndroidManifest.xml'),
    'utf8',
  );

  assert.match(gradle, /POLYCIRCLE_ANDROID_LOCAL_RELEASE_SMOKE/);
  assert.match(
    gradle,
    /manifestPlaceholders\["polycircleUsesCleartextTraffic"\] = "false"/,
  );
  assert.match(
    gradle,
    /allowLocalReleaseSmokeCleartext\.toString\(\)/,
  );
  assert.match(
    manifest,
    /android:usesCleartextTraffic="\$\{polycircleUsesCleartextTraffic\}"/,
  );
});
