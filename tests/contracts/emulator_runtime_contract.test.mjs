import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const runtime = read('lib/config/firebase_runtime.dart');
const main = read('lib/main.dart');
const seed = read('functions/scripts/seed_emulator.cjs');
const functionsPackage = JSON.parse(read('functions/package.json'));
const nvmrc = read('.nvmrc').trim();

test('Firebase emulator routing is explicit, guarded, and off by default', () => {
  assert.match(runtime, /USE_FIREBASE_EMULATORS/);
  assert.match(runtime, /defaultValue:\s*false/);
  assert.match(runtime, /POLYCIRCLE_LOCAL_RELEASE_SMOKE/);
  assert.match(runtime, /if \(!useFirebaseEmulators\)/);
  assert.match(runtime, /if \(!kDebugMode && !localReleaseSmoke\)/);
  assert.match(runtime, /Release emulator routing requires/);
  assert.match(main, /await configureFirebaseRuntime\(\);/);
});

test('local seed requires loopback emulator hosts before it can write anything', () => {
  assert.match(seed, /FIRESTORE_EMULATOR_HOST/);
  assert.match(seed, /FIREBASE_AUTH_EMULATOR_HOST/);
  assert.match(seed, /isLoopbackEmulatorHost/);
  assert.match(seed, /127\\\.0\\\.0\\\.1/);
  assert.match(seed, /Refusing to seed: emulator hosts must be loopback addresses/);
});

test('real Polycircle project ID is accepted only with explicit emulator-only acknowledgement', () => {
  assert.match(seed, /nativeFirebaseProjectId = 'poly-circle-j5v6dy'/);
  assert.match(seed, /POLYCIRCLE_ALLOW_REAL_PROJECT_EMULATOR/);
  assert.match(seed, /projectId === nativeFirebaseProjectId/);
  assert.match(seed, /projectId\.startsWith\('demo-'\)/);
});

test('Orbit stress fixtures are emulator-only and limited to reviewed densities', () => {
  assert.match(seed, /POLYCIRCLE_DISCOVER_FIXTURE_COUNT/);
  assert.match(seed, /new Set\(\[2, 5, 10, 15\]\)/);
  assert.match(seed, /discoverStressPeople\.slice\(0, discoverFixtureCount - 2\)/);
  assert.match(seed, /resetDiscoverFixtureState/);
  assert.match(seed, /local-discover-/);
  assert.match(seed, /discoverFixtureDistancesMiles/);
  assert.match(seed, /collection\('member_locations'\)/);
  assert.match(seed, /source: 'emulator_fixture'/);
  assert.doesNotMatch(read('lib/services/discovery_service.dart'), /local-discover-/);
});

test('nearby fixtures use fictional coordinates and never a developer location', () => {
  assert.match(seed, /latitude: 12\.3456/);
  assert.match(seed, /longitude: -45\.6789/);
  assert.doesNotMatch(seed, /navigator\.geolocation|CoreLocation|LocationManager/);
});

test('seeded profile and Circle fixtures stay inside production document schemas', () => {
  // Email and emulator-only auth claims belong to Auth/user records, never the
  // public profile document. The remaining fixture fields must stay compatible
  // with the production profile schema used by normal client editing.
  assert.match(
    seed,
    /const \{email: _email, authClaims: _authClaims, \.\.\.profile\} = person;/,
  );
  const profileSeed = seed.match(/async function seedPerson[\s\S]*?\n\}/)?.[0] ?? '';
  assert.match(profileSeed, /authClaims: _authClaims/);
  assert.doesNotMatch(profileSeed.match(/collection\('profiles'\)[\s\S]*?\n  \}\, \{merge: true\}\);/)?.[0] ?? '', /authClaims|email:/);
  assert.doesNotMatch(
    seed.match(/collection\('relationship_cards'\)[\s\S]*?\n  \}\);/)?.[0] ?? '',
    /cardId:/,
  );
});

test('Functions local tooling is pinned to Node 22 and exposes the seed command', () => {
  assert.equal(nvmrc, '22');
  assert.equal(functionsPackage.engines.node, '22');
  assert.equal(functionsPackage.scripts['seed:emulator'], 'node scripts/seed_emulator.cjs');
});
