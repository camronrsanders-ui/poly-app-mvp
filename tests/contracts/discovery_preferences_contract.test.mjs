import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const index = read('functions/src/index.ts');
const preferences = read('functions/src/discovery_preferences.ts');

test('discovery applies private preferences before returning profile views', () => {
  assert.match(index, /from '.\/discovery_preferences'/);
  const section = index.match(/export const getDiscoverCandidates[\s\S]*?export const likeProfile/)?.[0] ?? '';
  assert.match(section, /candidateMatchesPreferences\(requesterProfile, doc\.data\(\)\)/);
  assert.match(section, /toProfileView\(doc\.id, doc\.data\(\)\)/);
  assert.ok(
    section.indexOf('candidateMatchesPreferences') < section.lastIndexOf('toProfileView'),
    'Preference filtering must happen before a candidate is returned',
  );
});

test('discovery preference helper remains Firebase-initialization safe', () => {
  assert.doesNotMatch(preferences, /getFirestore|getStorage|getAuth|initializeApp/);
});

test('discovery preference helper covers age, structure and intention preferences', () => {
  assert.match(preferences, /ageMin/);
  assert.match(preferences, /ageMax/);
  assert.match(preferences, /preferredStructures/);
  assert.match(preferences, /preferredIntentions/);
  assert.match(preferences, /intentionTags/);
});

test('discovery scans a bounded candidate pool instead of an unbounded collection', () => {
  assert.match(index, /const scanLimit = Math\.min\(Math\.max\(limit \* 4, limit \+ 20\), 120\)/);
  assert.match(index, /\.limit\(scanLimit\)/);
});
