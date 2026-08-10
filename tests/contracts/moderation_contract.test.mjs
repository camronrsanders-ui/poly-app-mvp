import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const moderation = fs.readFileSync(path.join(root, 'functions/src/moderation.ts'), 'utf8');
const index = fs.readFileSync(path.join(root, 'functions/src/index.ts'), 'utf8');

test('moderation callables require a moderator or admin claim and App Check', () => {
  assert.match(moderation, /auth\.token\?\.moderator !== true && auth\.token\?\.admin !== true/);
  assert.match(moderation, /permission-denied', 'Moderator access required/);
  assert.equal((moderation.match(/enforceAppCheck:\s*true/g) ?? []).length, 2);
});

test('moderation queue is bounded and keeps private reviewer notes outside reporter-readable report docs', () => {
  assert.match(moderation, /Math\.min\(Math\.max\(Math\.trunc\(requestedLimit\), 1\), 100\)/);
  assert.match(moderation, /collection\('report_moderation'\)/);
  const review = moderation.match(/export const reviewModerationReport[\s\S]*$/)?.[0] ?? '';
  const reportWrite = review.match(/tx\.set\(reportRef,[\s\S]*?\}, \{merge: true\}\);/)?.[0] ?? '';
  assert.doesNotMatch(reportWrite, /moderatorUid|note/);
  assert.match(review, /tx\.set\(internalRef,[\s\S]*moderatorUid[\s\S]*note/);
});

test('moderation functions are exported by the deployed Functions entrypoint', () => {
  assert.match(index, /listModerationReports/);
  assert.match(index, /reviewModerationReport/);
});
