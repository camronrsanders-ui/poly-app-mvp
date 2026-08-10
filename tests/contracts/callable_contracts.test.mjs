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
const vaultUpload = read('functions/src/private_vault_upload.ts');
const vaultConsent = read('functions/src/private_vault_consent.ts');
const vaultListing = read('functions/src/private_vault_listing.ts');
const vaultGate = read('functions/src/private_vault_gate.ts');
const connectionEligibility = read('functions/src/connection_eligibility.ts');
const profileMedia = read('functions/src/profile_media.ts');
const profileMediaListing = read('functions/src/profile_media_listing.ts');
const profileView = read('functions/src/profile_view.ts');
const profileViewFields = read('functions/src/profile_view_fields.ts');
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

test('Trusted Like authorizes target state inside the same transaction as Like and Match writes', () => {
  assert.match(connectionEligibility, /profileVisibility'\)\s*!==\s*'public'/);
  assert.match(connectionEligibility, /openToConnections'\)\s*!==\s*true/);
  assert.doesNotMatch(connectionEligibility, /collection\(|getFirestore/,
    'Eligibility helper must validate a transaction-read snapshot, not perform an independent lookup');

  const section = index.match(/export const likeProfile[\s\S]*?export const createConversation/)?.[0] ?? '';
  const rateIndex = section.indexOf("consumeRateLimit(uid, 'like'");
  const targetReadIndex = section.indexOf('tx.get(targetUserRef)');
  assert.ok(rateIndex >= 0 && targetReadIndex >= 0 && rateIndex < targetReadIndex,
    'Like attempts must be rate-limited before target-specific reads');
  assert.match(section, /tx\.get\(callerUserRef\)/);
  assert.match(section, /tx\.get\(targetUserRef\)/);
  assert.match(section, /tx\.get\(targetProfileRef\)/);
  assert.match(section, /tx\.get\(outgoingBlockRef\)/);
  assert.match(section, /tx\.get\(incomingBlockRef\)/);
  assert.match(section, /tx\.get\(reverseRef\)/);
  assert.match(section, /tx\.get\(matchRef\)/);
  assert.match(section, /tx\.get\(passRef\)/);
  assert.match(section, /assertCanReceiveNewConnection\(targetProfile\)/);
});

test('Conversation creation authorizes both accounts, block state, and match in its write transaction', () => {
  const section = index.match(/export const createConversation[\s\S]*?export const deleteMyAccount/)?.[0] ?? '';
  const rateIndex = section.indexOf("consumeRateLimit(uid, 'conversation'");
  const targetReadIndex = section.indexOf('tx.get(targetUserRef)');
  assert.ok(rateIndex >= 0 && targetReadIndex >= 0 && rateIndex < targetReadIndex,
    'Conversation attempts must be rate-limited before target-specific reads');
  assert.match(section, /tx\.get\(callerUserRef\)/);
  assert.match(section, /tx\.get\(targetUserRef\)/);
  assert.match(section, /tx\.get\(outgoingBlockRef\)/);
  assert.match(section, /tx\.get\(incomingBlockRef\)/);
  assert.match(section, /tx\.get\(matchRef\)/);
  assert.match(section, /tx\.get\(ref\)/);
  assert.match(section, /Match integrity check failed/);
});

test('Private Vault stays product-disabled while revocation, cancellation, and reporting remain safety-available', () => {
  const flags = read('lib/config/feature_flags.dart');
  assert.match(flags, /privateVaultEnabled\s*=\s*false/);
  assert.match(vaultGate, /privateVaultServerEnabled\s*=\s*false/);
  assert.match(vaultGate, /assertPrivateVaultEnabled/);
  assert.match(vault, /function requireUid[\s\S]*assertPrivateVaultEnabled\(\)/);
  assert.match(vaultListing, /assertPrivateVaultEnabled/);
  assert.match(vaultUpload, /assertPrivateVaultEnabled/);
  assert.doesNotMatch(vaultConsent, /assertPrivateVaultEnabled/,
    'Consent withdrawal must remain available during a Vault kill-switch event');

  const revoke = vault.match(/export const revokePrivateMedia[\s\S]*?export const getPrivateMediaAccess/)?.[0] ?? '';
  const report = vault.match(/export const reportPrivateMedia[\s\S]*$/)?.[0] ?? '';
  assert.match(revoke, /requireAuthenticatedUid\(request\.auth\)/);
  assert.doesNotMatch(revoke, /requireUid\(request\.auth\)/);
  assert.match(report, /requireAuthenticatedUid\(request\.auth\)/);
  assert.doesNotMatch(report, /requireUid\(request\.auth\)/);

  assert.match(vaultUpload, /if \(!privateVaultServerEnabled\)/,
    'Storage-triggered Private Vault processing must also honor the server kill switch');
  assert.match(vaultUpload, /rejectionReason:\s*'feature_disabled'/);
});

test('Private Vault trusted sharing functions are exported by backend', () => {
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

test('Private Vault grant transaction requires current accepted consent plus live pair/media state', () => {
  const section = vault.match(/export const grantPrivateMedia[\s\S]*?export const revokePrivateMedia/)?.[0] ?? '';
  assert.match(vault, /function requireAcceptedShareRequest\b/);
  assert.match(section, /db\.runTransaction/);
  assert.match(section, /tx\.get\(ownerRef\)/);
  assert.match(section, /tx\.get\(recipientRef\)/);
  assert.match(section, /tx\.get\(abRef\)/);
  assert.match(section, /tx\.get\(baRef\)/);
  assert.match(section, /tx\.get\(matchRef\)/);
  assert.match(section, /tx\.get\(acceptedRequestRef\)/);
  assert.match(section, /tx\.get\(mediaRef\)/);
  assert.match(section, /tx\.get\(grantRef\)/);
  assert.match(section, /requireAcceptedShareRequest\(acceptedRequest, ownerUid, recipientUid\)/);
  assert.match(section, /tx\.set\(grantRef/);
});

test('Private Vault request response and optional privacy preference commit atomically with pair authorization', () => {
  const section = vault.match(/export const respondToPrivateMediaRequest[\s\S]*?export const clearPrivateMediaRequestPreference/)?.[0] ?? '';
  assert.match(section, /db\.runTransaction/);
  assert.match(section, /tx\.get\(ref\)/);
  assert.match(section, /assertEligiblePairSnapshots/);
  assert.match(section, /tx\.set\(ref/);
  assert.match(section, /private_media_request_preferences/);
});

test('Private Vault recipient withdrawal makes cancelled request authoritative before exhaustive grant cleanup', () => {
  assert.match(vaultConsent, /export const cancelPrivateMediaRequest\b/);
  assert.match(index, /export \{cancelPrivateMediaRequest\} from '.\/private_vault_consent'/);
  assert.match(vaultConsent, /db\.runTransaction/);
  assert.match(vaultConsent, /status:\s*'cancelled'/);
  assert.match(vaultConsent, /where\('ownerUid', '==', ownerUid\)/);
  assert.match(vaultConsent, /where\('recipientUid', '==', requesterUid\)/);
  assert.match(vaultConsent, /where\('active', '==', true\)/);
  assert.doesNotMatch(vaultConsent, /\.limit\(/);
  assert.match(vaultConsent, /revokedReason:\s*'recipient_cancelled_request'/);
  assert.match(vaultConsent, /active:\s*false/);
  const cancelIndex = vaultConsent.indexOf("status: 'cancelled'");
  const grantQueryIndex = vaultConsent.indexOf("db.collection('private_media_grants')");
  assert.ok(cancelIndex >= 0 && grantQueryIndex > cancelIndex,
    'Authoritative consent cancellation must commit before grant cleanup begins');
  assert.match(index, /'private_media_request_cancel'/);
});

test('Private Vault access requires both an active grant and still-accepted consent', () => {
  const section = vault.match(/export const getPrivateMediaAccess[\s\S]*?export const reportPrivateMedia/)?.[0] ?? '';
  assert.match(section, /private_media_grants/);
  assert.match(section, /private_media_requests/);
  assert.match(section, /requireAcceptedShareRequest\(acceptedRequest, ownerUid, recipientUid\)/);
  assert.match(section, /grant\.get\('active'\) !== true/);
});

test('Private Vault listings batch authorization and consent reads instead of N+1 peer lookups', () => {
  for (const name of [
    'listMyPrivateMediaRequests',
    'listMyPrivateMediaShares',
    'listMyPrivateMediaInbox',
  ]) {
    assert.match(vaultListing, new RegExp(`export const ${name}\\b`), `${name} is missing from private_vault_listing.ts`);
    assert.match(index, new RegExp(`export \\{[^}]*\\b${name}\\b[^}]*\\} from './private_vault_listing'`), `${name} is not re-exported from index.ts`);
  }
  assert.match(vaultListing, /async function loadPeerContext/);
  assert.match(vaultListing, /async function loadAcceptedRecipients/);
  assert.match(vaultListing, /async function loadAcceptedOwners/);
  assert.match(vaultListing, /db\.getAll\(\.\.\.userRefs\)/);
  assert.match(vaultListing, /db\.getAll\(\.\.\.profileRefs\)/);
  assert.match(vaultListing, /db\.getAll\(\.\.\.blockRefs\)/);
  assert.match(vaultListing, /db\.getAll\(\.\.\.matchRefs\)/);
  assert.match(vaultListing, /db\.getAll\(\.\.\.requestRefs\)/);
  assert.doesNotMatch(vaultListing, /async function pairIsEligible|async function displayName/);
});

test('Private Vault listings expose safe metadata only', () => {
  assert.doesNotMatch(vaultListing, /storagePath|quarantinePath|uploadUrl|signedUrl/);
  assert.match(vaultListing, /maxRequestsPerDirection\s*=\s*50/);
  assert.match(vaultListing, /maxGrantsPerListing\s*=\s*100/);
});

test('Private Vault upload pipeline stays trusted, consent-gated, rate-limited, and staff-reviewed', () => {
  for (const name of [
    'beginPrivateMediaUpload',
    'confirmPrivateMediaUpload',
    'processPrivateMedia',
    'reviewPrivateMedia',
    'listMyPrivateMedia',
  ]) {
    assert.match(vaultUpload, new RegExp(`export const ${name}\\b`), `${name} is missing from private_vault_upload.ts`);
    assert.match(index, new RegExp(`export \\{[^}]*\\b${name}\\b[^}]*\\} from './private_vault_upload'`), `${name} is not re-exported from index.ts`);
  }
  assert.match(vaultUpload, /allSubjectsAdults\s*!==\s*true/);
  assert.match(vaultUpload, /sharingRightsConfirmed\s*!==\s*true/);
  assert.match(vaultUpload, /processed_pending_review/);
  assert.match(vaultUpload, /moderator.*admin.*superadmin/s);
  assert.match(vaultUpload, /consumeRateLimit\(ownerUid, 'private_media_confirm'/);
  assert.match(vaultUpload, /consumeRateLimit\(reviewerUid, 'private_media_review'/);
  assert.match(vaultUpload, /consumeRateLimit\(ownerUid, 'private_media_list'/);
  assert.match(vaultUpload, /assertActive\(reviewerUid\)/);
});

test('Private Vault owner revocation is active-account gated, transaction-safe, and records one canonical reason field', () => {
  const section = vault.match(/export const revokePrivateMedia[\s\S]*?export const getPrivateMediaAccess/)?.[0] ?? '';
  assert.match(section, /requireAuthenticatedUid\(request\.auth\)/);
  assert.match(section, /assertActive\(ownerUid\)/);
  assert.match(section, /db\.runTransaction/);
  assert.match(section, /tx\.get\(grantRef\)/);
  assert.match(section, /revokedReason:\s*'owner_revoked'/);
  assert.doesNotMatch(section, /revocationReason/);
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
      profileViewFields,
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

test('Helpers imported before initializeApp stay Firebase-initialization safe', () => {
  assert.match(index, /from '.\/profile_view_fields'/);
  assert.match(index, /from '.\/connection_eligibility'/);
  assert.doesNotMatch(profileViewFields, /getFirestore|getStorage|getAuth|initializeApp/);
  assert.doesNotMatch(connectionEligibility, /getFirestore|getStorage|getAuth|initializeApp/);
});
