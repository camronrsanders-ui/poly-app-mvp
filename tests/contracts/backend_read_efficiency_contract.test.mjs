import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const index = fs.readFileSync(path.join(root, 'functions/src/index.ts'), 'utf8');
const profileView = fs.readFileSync(path.join(root, 'functions/src/profile_view.ts'), 'utf8');

test('Discover sanitizes malformed limits and batches block checks', () => {
  const section = index.match(/export const getDiscoverCandidates[\s\S]*?export const likeProfile/)?.[0] ?? '';
  assert.match(section, /Number\.isFinite\(requestedLimit\)/);
  assert.match(section, /Math\.trunc\(requestedLimit\)/);
  assert.match(section, /blockRefs/);
  assert.match(section, /db\.getAll\(\.\.\.blockRefs\)/);
  assert.match(section, /blocked\.has\(doc\.id\)/);
  assert.doesNotMatch(section, /await isBlocked\(uid, doc\.id\)/);
});

test('connection listing caps fan-out and batches per-connection reads', () => {
  assert.match(profileView, /maxConnectionsPerResponse = 100/);
  assert.match(profileView, /records\.length >= maxConnectionsPerResponse/);
  assert.match(profileView, /db\.getAll\(\.\.\.userRefs\)/);
  assert.match(profileView, /db\.getAll\(\.\.\.profileRefs\)/);
  assert.match(profileView, /db\.getAll\(\.\.\.conversationRefs\)/);
  assert.match(profileView, /db\.getAll\(\.\.\.blockRefs\)/);
  assert.doesNotMatch(profileView, /for \([\s\S]*await isBlocked\(/);
});
