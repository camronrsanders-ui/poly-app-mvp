import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const index = fs.readFileSync(path.join(root, 'functions/src/index.ts'), 'utf8');
const auth = fs.readFileSync(path.join(root, 'lib/services/auth_service.dart'), 'utf8');
const accountService = fs.readFileSync(path.join(root, 'lib/services/account_service.dart'), 'utf8');
const app = fs.readFileSync(path.join(root, 'lib/app.dart'), 'utf8');

const deletion = index.match(/export const deleteMyAccount[\s\S]*?export \{blockUser/)?.[0] ?? '';

test('storage cleanup failure cannot be swallowed before Auth deletion', () => {
  assert.match(deletion, /await Promise\.all\(\[[\s\S]*bucket\.deleteFiles/);
  assert.doesNotMatch(deletion, /bucket\.deleteFiles\([^\n]+\)\.catch\(/);
  const storageIndex = deletion.indexOf('bucket.deleteFiles');
  const authDeleteIndex = deletion.indexOf('getAuth().deleteUser(uid)');
  assert.ok(storageIndex >= 0 && authDeleteIndex > storageIndex,
    'Private Storage cleanup must complete before Auth deletion.');
});

test('failed deletion leaves a minimal recoverable paused account marker with original request time', () => {
  assert.match(deletion, /minimalPendingAccount/);
  assert.match(deletion, /accountStatus:\s*'paused'/);
  assert.match(deletion, /originalDeletionRequestedAt/);
  assert.match(deletion, /deletionRequestedAt:\s*originalDeletionRequestedAt/);
  assert.doesNotMatch(
    deletion.match(/const minimalPendingAccount[\s\S]*?\}\);/)?.[0] ?? '',
    /email|onboardingComplete|lastActiveAt/,
  );
  assert.match(deletion, /Account deletion is still pending\. Sign in again and retry deletion/);
});

test('deletion retries preserve the original marker and receive a recovery-sized rate budget', () => {
  assert.match(
    deletion,
    /const deletionPending\s*=\s*userState\.get\('accountStatus'\)\s*===\s*'paused'/,
  );
  assert.match(deletion, /deletionPending \? 20 : 2/);
  assert.match(deletion, /if \(!deletionPending\)[\s\S]*deletionRequestedAt:\s*FieldValue\.serverTimestamp\(\)/);
  const pendingMarkerIndex = deletion.indexOf('const deletionPending');
  const pauseWriteIndex = deletion.indexOf("accountStatus: 'paused'", pendingMarkerIndex);
  assert.ok(pendingMarkerIndex >= 0 && pauseWriteIndex > pendingMarkerIndex);
});

test('Private Vault user-scoped rate limits are included in deletion cleanup', () => {
  for (const action of [
    'private_media_preference_clear',
    'private_media_confirm',
    'private_media_review',
    'private_media_list',
  ]) {
    assert.match(deletion, new RegExp(`'${action}'`), `${action} must be cleaned on deletion`);
  }
});

test('profile-media and moderation rate limits stay covered by account deletion cleanup', () => {
  for (const action of [
    'profile_photo_upload',
    'profile_photo_confirm',
    'profile_photo_review',
    'profile_photo_access',
    'profile_photo_delete',
    'profile_photo_list',
    'profile_photo_moderation_list',
    'moderation_list',
    'moderation_review',
    'moderation_account',
  ]) {
    assert.match(deletion, new RegExp(`'${action}'`), `${action} must be cleaned on deletion`);
  }
});

test('client login and session gate permit only deletion-pending paused accounts into recovery', () => {
  assert.match(auth, /status == 'paused' && data\?\['deletionRequestedAt'\] != null/);
  assert.match(auth, /status != 'active' && !deletionPending/);
  assert.match(app, /status == 'paused' && account\['deletionRequestedAt'\] != null/);
  assert.match(app, /_DeletionRecoveryScreen/);
  assert.match(app, /if \(status != 'active'\)[\s\S]*_AccountUnavailableScreen/);
});

test('deletion client signs out on stale-auth or retryable backend cleanup failure', () => {
  assert.match(accountService, /on FirebaseFunctionsException catch \(error\)/);
  assert.match(accountService, /error\.code == 'failed-precondition' \|\| error\.code == 'internal'/);
  assert.match(accountService, /await _auth\.signOut\(\)/);
});

test('final Firestore tombstone contains no profile/email data if its deletion fails after Auth removal', () => {
  const authDeleteIndex = deletion.indexOf('getAuth().deleteUser(uid)');
  const finalUserDeleteIndex = deletion.lastIndexOf('userRef.delete()');
  assert.ok(authDeleteIndex >= 0 && finalUserDeleteIndex > authDeleteIndex);
  assert.match(deletion, /Failed to remove minimal account deletion tombstone after Auth deletion/);
});
