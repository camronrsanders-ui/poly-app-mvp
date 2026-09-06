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
  const section = index.match(/async function eligibleDiscoverCandidates[\s\S]*?return eligible;\n\}/)?.[0] ?? '';
  assert.match(section, /candidateMatchesPreferences\(requesterProfile, data\)/);
  assert.match(section, /toProfileView\(doc\.id, data\)/);
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
  assert.match(index, /maximumDiscoverCandidatePool/);
  assert.match(index, /\.limit\(maximumDiscoverCandidatePool\)/);
});
