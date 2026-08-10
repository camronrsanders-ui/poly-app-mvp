import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const index = fs.readFileSync(path.join(root, 'functions/src/index.ts'), 'utf8');
const auth = fs.readFileSync(path.join(root, 'lib/services/auth_service.dart'), 'utf8');
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

test('failed deletion leaves a minimal recoverable paused account marker', () => {
  assert.match(deletion, /minimalPendingAccount/);
  assert.match(deletion, /accountStatus:\s*'paused'/);
  assert.match(deletion, /deletionRequestedAt:\s*FieldValue\.serverTimestamp\(\)/);
  assert.doesNotMatch(
    deletion.match(/const minimalPendingAccount[\s\S]*?\}\);/)?.[0] ?? '',
    /email|onboardingComplete|lastActiveAt/,
  );
  assert.match(deletion, /Account deletion is still pending\. Sign in again and retry deletion/);
});

test('client login and session gate permit only deletion-pending paused accounts into recovery', () => {
  assert.match(auth, /status == 'paused' && data\?\['deletionRequestedAt'\] != null/);
  assert.match(auth, /status != 'active' && !deletionPending/);
  assert.match(app, /status == 'paused' && account\['deletionRequestedAt'\] != null/);
  assert.match(app, /_DeletionRecoveryScreen/);
  assert.match(app, /if \(status != 'active'\)[\s\S]*_AccountUnavailableScreen/);
});

test('final Firestore tombstone contains no profile/email data if its deletion fails after Auth removal', () => {
  const authDeleteIndex = deletion.indexOf('getAuth().deleteUser(uid)');
  const finalUserDeleteIndex = deletion.lastIndexOf('userRef.delete()');
  assert.ok(authDeleteIndex >= 0 && finalUserDeleteIndex > authDeleteIndex);
  assert.match(deletion, /Failed to remove minimal account deletion tombstone after Auth deletion/);
});
