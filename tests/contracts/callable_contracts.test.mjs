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
const discoveryService = read('lib/services/discovery_service.dart');
const connectionService = read('lib/services/connection_service.dart');
const messagingService = read('lib/services/messaging_service.dart');
const safetyService = read('lib/services/safety_service.dart');
const profileMediaService = read('lib/services/profile_media_service.dart');

const callableContracts = [
  {name: 'getDiscoverCandidates', client: discoveryService, backend: index},
  {name: 'likeProfile', client: connectionService, backend: index},
  {name: 'createConversation', client: messagingService, backend: index},
  {name: 'blockUser', client: safetyService, backend: `${index}\n${safety}`},
  {name: 'unblockUser', client: safetyService, backend: `${index}\n${safety}`},
  {name: 'endConnection', client: connectionService, backend: `${index}\n${safety}`},
  {name: 'submitReport', client: safetyService, backend: `${index}\n${safety}`},
  {name: 'beginProfilePhotoUpload', client: profileMediaService, backend: `${index}\n${profileMedia}`},
  {name: 'confirmProfilePhotoUpload', client: profileMediaService, backend: `${index}\n${profileMedia}`},
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
