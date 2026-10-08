import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const dataAccess = fs.readFileSync(path.join(root, 'functions/src/data_access.ts'), 'utf8');
const index = fs.readFileSync(path.join(root, 'functions/src/index.ts'), 'utf8');

test('member data snapshot requires App Check, active account, recent auth, and a daily rate limit', () => {
  assert.match(dataAccess, /export const getMyDataSnapshot = onCall/);
  assert.match(dataAccess, /enforceAppCheck:\s*true/);
  assert.match(dataAccess, /assertActive\(uid\)/);
  assert.match(dataAccess, /auth_time/);
  assert.match(dataAccess, /10 \* 60_000/);
  assert.match(dataAccess, /action = 'data_snapshot'/);
  assert.match(dataAccess, /const max = 3/);
});

test('member data snapshot is explicitly bounded and reports truncated categories', () => {
  assert.match(dataAccess, /snapshotIsBounded:\s*true/);
  assert.match(dataAccess, /truncatedCategories/);
  assert.match(dataAccess, /sentMessages:\s*1000/);
  assert.match(dataAccess, /reports:\s*500/);
  assert.match(dataAccess, /profileMedia:\s*100/);
  assert.match(dataAccess, /privateMedia:\s*100/);
});

test('media snapshot intentionally omits Storage paths and signed URLs', () => {
  const returned = dataAccess.match(/return \{[\s\S]*?\n    \};\n  \},\n\);/)?.[0] ?? '';
  assert.doesNotMatch(returned, /storagePath|signedUrl|previewUrl|uploadUrl/);
});

test('member snapshot never exports internal moderation collections or incoming reports', () => {
  assert.doesNotMatch(dataAccess, /collection\('report_moderation'\)/);
  assert.doesNotMatch(dataAccess, /collection\('account_moderation'\)/);
  assert.doesNotMatch(dataAccess, /collection\('moderation_audit'\)/);
  assert.doesNotMatch(dataAccess, /where\('reportedUid', '==', uid\)/);
});

test('data snapshot is exported by the Functions entrypoint', () => {
  assert.match(index, /getMyDataSnapshot/);
});
