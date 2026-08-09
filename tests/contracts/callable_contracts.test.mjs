import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

const index = read('functions/src/index.ts');
const safety = read('functions/src/safety.ts');
const vault = read('functions/src/private_vault.ts');
const profileMedia = read('functions/src/profile_media.ts');
const profileMediaListing = read('functions/src/profile_media_listing.ts');
const profileView = read('functions/src/profile_view.ts');
const discoveryService = read('lib/services/discovery_service.dart');
const connectionService = read('lib/services/connection_service.dart');
const messagingService = read('lib/services/messaging_service.dart');
const safetyService = read('lib/services/safety_service.dart');
const profileMediaService = read('lib/services/profile_media_service.dart');
const accountService = read('lib/services/account_service.dart');
const connectionsScreen = read('lib/screens/connections/connections_screen.dart');

const callableContracts = [
  {name: 'getDiscoverCandidates', client: discoveryService, backend: index},
  {name: 'likeProfile', client: connectionService, backend: index},
  {name: 'listMyConnections', client: connectionService, backend: `${index}\n${profileView}`},
  {name: 'createConversation', client: messagingService, backend: index},
  {name: 'deleteMyAccount', client: accountService, backend: index},
  {name: 'blockUser', client: safetyService, backend: `${index}\n${safety}`},
  {name: 'unblockUser', client: safetyService, backend: `${index}\n${safety}`},
  {name: 'endConnection', client: connectionService, backend: `${index}\n${safety}`},
  {name: 'submitReport', client: safetyService, backend: `${index}\n${safety}`},
  {name: 'beginProfilePhotoUpload', client: profileMediaService, backend: `${index}\n${profileMedia}`},
  {name: 'confirmProfilePhotoUpload', client: profileMediaService, backend: `${index}\n${profileMedia}`},
  {name: 'listMyProfilePhotos', client: profileMediaService, backend: `${index}\n${profileMediaListing}`},
  {name: 'getProfilePhotoAccess', client: profileMediaService, backend: `${index}\n${profileMedia}`},
  {name: 'deleteProfilePhoto', client: profileMediaService, backend: `${index}\n${profileMedia}`},
];

for (const contract of callableContracts) {
  test(`Flutter callable ${contract.name} has a backend export`, () => {
    assert.match(
      contract.client,
      new RegExp(`httpsCallable\\(['\"]${contract.name}['\"]\\)`),
      `Flutter no longer calls ${contract.name}`,
    );
    assert.match(
      contract.backend,
      new RegExp(`(?:export const ${contract.name}|export \\{[^}]*\\b${contract.name}\\b[^}]*\\})`),
      `Backend no longer exports ${contract.name}`,
    );
  });
}

test('Account deletion requires explicit DELETE confirmation from the trusted client service', () => {
  assert.match(accountService, /'confirmation':\s*'DELETE'/);
  assert.match(index, /confirmation\s*\?\?\s*''\)\s*!==\s*'DELETE'/);
});

test('Private Vault remains disabled in Flutter until release gates pass', () => {
  const flags = read('lib/config/feature_flags.dart');
  assert.match(flags, /privateVaultEnabled\s*=\s*false/);
});

test('Private Vault trusted functions are exported by backend', () => {
  for (const name of [
    'grantPrivateMedia',
    'revokePrivateMedia',
    'getPrivateMediaAccess',
    'requestPrivateMedia',
    'respondToPrivateMediaRequest',
    'reportPrivateMedia',
  ]) {
    assert.match(vault, new RegExp(`export const ${name}\\b`), `${name} is missing from private_vault.ts`);
    assert.match(index, new RegExp(`export \\{[^}]*\\b${name}\\b[^}]*\\} from './private_vault'`), `${name} is not re-exported from index.ts`);
  }
});

test('Profile media moderation stays backend-only', () => {
  assert.match(profileMedia, /export const reviewProfilePhoto\b/);
  assert.match(index, /export \{[^}]*\breviewProfilePhoto\b[^}]*\} from '.\/profile_media'/);
  assert.doesNotMatch(profileMediaService, /httpsCallable\(['"]reviewProfilePhoto['"]\)/);
});

test('Public profile model never stores permanent media URLs', () => {
  const profileModel = read('lib/models/profile.dart');
  const onboarding = read('lib/screens/onboarding/onboarding_screen.dart');
  assert.doesNotMatch(profileModel, /photoUrls|avatarUrl/);
  assert.doesNotMatch(onboarding, /photoUrls|avatarUrl/);
});

test('Discovery and connection profile views do not expose private preference fields', () => {
  for (const privateKey of [
    'ageMin',
    'ageMax',
    'distanceRadius',
    'preferredStructures',
    'preferredIntentions',
    'mapVisibility',
    'profileVisibility',
    'createdAt',
    'updatedAt',
  ]) {
    assert.doesNotMatch(
      profileView,
      new RegExp(`['\"]${privateKey}['\"]`),
      `${privateKey} must not be included in trusted public profile views`,
    );
  }
});

test('Connections screen does not bypass trusted profile views with direct Firestore profile reads', () => {
  assert.doesNotMatch(connectionsScreen, /cloud_firestore/);
  assert.doesNotMatch(connectionsScreen, /collection\(['"]profiles['"]\)/);
});

test('Firestore index config includes the public-and-open discovery query index', () => {
  const config = JSON.parse(read('firestore.indexes.json'));
  const discoveryIndex = config.indexes.find((entry) => {
    if (entry.collectionGroup !== 'profiles') return false;
    const fields = new Set(entry.fields.map((field) => field.fieldPath));
    return fields.has('profileVisibility') && fields.has('openToConnections');
  });
  assert.ok(discoveryIndex, 'Missing composite index for profileVisibility + openToConnections');
});
