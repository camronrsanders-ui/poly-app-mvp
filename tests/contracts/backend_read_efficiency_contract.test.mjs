import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const index = fs.readFileSync(path.join(root, 'functions/src/index.ts'), 'utf8');
const pagination = fs.readFileSync(
  path.join(root, 'functions/src/discovery_pagination.ts'),
  'utf8',
);
const profileView = fs.readFileSync(path.join(root, 'functions/src/profile_view.ts'), 'utf8');

test('Discover sanitizes malformed limits and batches block checks', () => {
  const section = index.match(/export const getDiscoverCandidates[\s\S]*?export const likeProfile/)?.[0] ?? '';
  const eligibility = index.match(/async function eligibleDiscoverCandidates[\s\S]*?return eligible;\n\}/)?.[0] ?? '';
  assert.match(pagination, /Number\.isFinite\(requested\)/);
  assert.match(pagination, /Math\.trunc\(requested\)/);
  assert.match(eligibility, /blockRefs/);
  assert.match(eligibility, /db\.getAll\(\.\.\.blockRefs\)/);
  assert.match(eligibility, /blocked\.has\(doc\.id\)/);
  assert.doesNotMatch(eligibility, /await isBlocked\(uid, doc\.id\)/);
  assert.match(section, /eligibleDiscoverCandidates/);
});

test('connection listing filters active matches before its cap and batches fan-out reads', () => {
  assert.match(profileView, /maxConnectionsPerResponse = 100/);
  assert.match(profileView, /where\('userAUid', '==', uid\)[\s\S]*?where\('active', '==', true\)[\s\S]*?limit\(maxConnectionsPerResponse\)/);
  assert.match(profileView, /where\('userBUid', '==', uid\)[\s\S]*?where\('active', '==', true\)[\s\S]*?limit\(maxConnectionsPerResponse\)/);
  assert.match(profileView, /records\.length >= maxConnectionsPerResponse/);
  assert.match(profileView, /db\.getAll\(\.\.\.userRefs\)/);
  assert.match(profileView, /db\.getAll\(\.\.\.profileRefs\)/);
  assert.match(profileView, /db\.getAll\(\.\.\.conversationRefs\)/);
  assert.match(profileView, /db\.getAll\(\.\.\.blockRefs\)/);
  assert.doesNotMatch(profileView, /for \([\s\S]*await isBlocked\(/);
});
