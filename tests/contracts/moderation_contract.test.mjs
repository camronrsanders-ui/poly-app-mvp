import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const moderation = fs.readFileSync(path.join(root, 'functions/src/moderation.ts'), 'utf8');
const index = fs.readFileSync(path.join(root, 'functions/src/index.ts'), 'utf8');

test('moderation callables require trusted claims and App Check', () => {
  assert.match(moderation, /auth\.token\?\.moderator !== true && auth\.token\?\.admin !== true/);
  assert.match(moderation, /Administrator access required/);
  assert.equal((moderation.match(/enforceAppCheck:\s*true/g) ?? []).length, 3);
});

test('moderation queue is bounded and keeps private reviewer notes outside reporter-readable report docs', () => {
  assert.match(moderation, /Math\.min\(Math\.max\(Math\.trunc\(requestedLimit\), 1\), 100\)/);
  assert.match(moderation, /collection\('report_moderation'\)/);
  const review = moderation.match(/export const reviewModerationReport[\s\S]*?export const setAccountModerationState/)?.[0] ?? '';
  const reportWrite = review.match(/tx\.set\(reportRef,[\s\S]*?\}, \{merge: true\}\);/)?.[0] ?? '';
  assert.doesNotMatch(reportWrite, /moderatorUid|note/);
  assert.match(review, /tx\.set\(internalRef,[\s\S]*moderatorUid[\s\S]*note/);
});

test('account moderation is admin-only and protects privileged targets', () => {
  const section = moderation.match(/export const setAccountModerationState[\s\S]*$/)?.[0] ?? '';
  assert.match(section, /requireAdmin\(request\.auth\)/);
  assert.match(section, /targetPrivileged/);
  assert.match(section, /superadmin/);
  assert.match(section, /pending deletion cannot be moderated into another state/);
});

test('ban fails closed immediately and terminates interaction without rewriting last message time', () => {
  assert.match(moderation, /await userRef\.set\(\{accountStatus: state\}/);
  assert.match(moderation, /updateUser\(targetUid, \{disabled: state === 'banned'\}\)/);
  const cleanup = moderation.match(/async function terminateForBan[\s\S]*?export const listModerationReports/)?.[0] ?? '';
  assert.match(cleanup, /active:\s*false/);
  assert.match(cleanup, /endedReason:\s*'moderation_ban'/);
  assert.match(cleanup, /revokedReason:\s*'moderation_ban'/);
  assert.match(cleanup, /cancelledReason:\s*'moderation_ban'/);
  assert.doesNotMatch(cleanup, /lastMessageAt/);
});

test('moderation functions are exported by the deployed Functions entrypoint', () => {
  assert.match(index, /listModerationReports/);
  assert.match(index, /reviewModerationReport/);
  assert.match(index, /setAccountModerationState/);
});
