import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const fixtureDirectory = path.join(
  root,
  'functions/fixtures/discover_portraits',
);
const seed = fs.readFileSync(
  path.join(root, 'functions/scripts/seed_emulator.cjs'),
  'utf8',
);

test('Discover portrait fixtures are bounded fictional JPEG assets', () => {
  const files = fs.readdirSync(fixtureDirectory)
    .filter((name) => name.endsWith('.jpg'))
    .sort();

  assert.deepEqual(
    files,
    Array.from(
      {length: 15},
      (_, index) => `profile-${String(index + 1).padStart(2, '0')}.jpg`,
    ),
  );
  for (const file of files) {
    const bytes = fs.readFileSync(path.join(fixtureDirectory, file));
    assert.deepEqual([...bytes.subarray(0, 3)], [0xff, 0xd8, 0xff]);
    assert.ok(bytes.length > 10_000);
    assert.ok(bytes.length < 500_000);
  }

  const readme = fs.readFileSync(path.join(fixtureDirectory, 'README.md'), 'utf8');
  assert.match(readme, /fictional, AI-generated test assets/);
  assert.match(readme, /production code does not reference them/);
});

test('portrait fixtures flow through protected media only inside emulators', () => {
  assert.match(seed, /FIREBASE_STORAGE_EMULATOR_HOST/);
  assert.match(seed, /isLoopbackEmulatorHost\(storageHost\)/);
  assert.match(seed, /discoverPortraitDirectory/);
  assert.match(seed, /bucket\.file\(storagePath\)/);
  assert.match(seed, /collection\('profile_media'\)/);
  assert.match(seed, /emulatorFixture: true/);
  assert.match(seed, /\(index % 15\) \+ 1/);
  assert.match(seed, /saveDiscoverFixturePhoto/);
  assert.match(seed, /maximumAttempts = 4/);
  assert.match(seed, /waitForLocalEmulator\(250\)/);
  assert.match(seed, /seedDiscoverPhotos\(\)/);

  for (const clientPath of [
    'lib/screens/discover/discover_screen.dart',
    'lib/services/discovery_service.dart',
    'lib/services/profile_media_service.dart',
  ]) {
    const client = fs.readFileSync(path.join(root, clientPath), 'utf8');
    assert.doesNotMatch(client, /discover_portraits|local-discover-photo/);
  }
});
