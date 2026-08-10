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

test('Firebase emulator routing is explicit, debug-only, and off by default', () => {
  assert.match(runtime, /USE_FIREBASE_EMULATORS/);
  assert.match(runtime, /defaultValue:\s*false/);
  assert.match(runtime, /if \(!kDebugMode \|\| !useFirebaseEmulators\) return;/);
  assert.match(main, /await configureFirebaseRuntime\(\);/);
});

test('local seed refuses to run without emulator hosts and a demo project', () => {
  assert.match(seed, /FIRESTORE_EMULATOR_HOST/);
  assert.match(seed, /FIREBASE_AUTH_EMULATOR_HOST/);
  assert.match(seed, /if \(!firestoreHost \|\| !authHost\)/);
  assert.match(seed, /if \(!projectId\.startsWith\('demo-'\)\)/);
  assert.match(seed, /Refusing to seed non-demo project/);
});

test('seeded profile and Circle fixtures stay inside production document schemas', () => {
  assert.match(seed, /const \{email: _email, \.\.\.profile\} = person;/);
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
