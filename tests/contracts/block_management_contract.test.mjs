import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const safetyBackend = fs.readFileSync(path.join(root, 'functions/src/safety.ts'), 'utf8');
const index = fs.readFileSync(path.join(root, 'functions/src/index.ts'), 'utf8');
const safetyService = fs.readFileSync(path.join(root, 'lib/services/safety_service.dart'), 'utf8');
const safetyCenter = fs.readFileSync(path.join(root, 'lib/screens/safety/safety_center_screen.dart'), 'utf8');

test('blocked-member listing stays behind trusted callable boundary', () => {
  assert.match(safetyBackend, /export const listMyBlocks = onCall/);
  assert.match(safetyBackend, /enforceAppCheck:\s*true/);
  assert.match(safetyBackend, /assertActive\(uid\)/);
  assert.match(safetyBackend, /enforceRateLimit\(uid, 'block_list'/);
  assert.match(safetyBackend, /\.where\('blockerUid', '==', uid\)/);
  assert.match(safetyBackend, /\.limit\(200\)/);
  assert.match(index, /export \{[^}]*listMyBlocks[^}]*\} from '.\/safety'/);
});

test('blocked-member listing returns minimal management metadata only', () => {
  const section = safetyBackend.match(/export const listMyBlocks[\s\S]*?export const endConnection/)?.[0] ?? '';
  assert.match(section, /blockedUid/);
  assert.match(section, /displayName/);
  assert.match(section, /createdAtMs/);
  assert.doesNotMatch(section, /bio|orientation|relationshipStructure|lookingForNote|intentionTags/);
});

test('unblock re-revokes private access before removing the block', () => {
  const section = safetyBackend.match(/export const unblockUser[\s\S]*?export const listMyBlocks/)?.[0] ?? '';
  assert.match(section, /const block = await blockRef\.get\(\)/);
  assert.match(section, /revokePrivateAccessBetween\(blockerUid, blockedUid, 'unblocked_after_block'\)/);
  assert.match(section, /await blockRef\.delete\(\)/);
  assert.ok(
    section.indexOf('revokePrivateAccessBetween') < section.indexOf('await blockRef.delete()'),
    'private grants must be revoked before the block disappears',
  );
});

test('Safety Center can list and unblock without restoring old connections', () => {
  assert.match(safetyService, /httpsCallable\('listMyBlocks'\)/);
  assert.match(safetyCenter, /Manage blocked members/);
  assert.match(safetyCenter, /_safety\.unblockUser\(uid\)/);
  assert.match(safetyCenter, /does not restore a previous match, conversation, or private-media access/);
});
