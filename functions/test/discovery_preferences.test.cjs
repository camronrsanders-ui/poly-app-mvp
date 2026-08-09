const test = require('node:test');
const assert = require('node:assert/strict');
const {candidateMatchesPreferences} = require('../lib/discovery_preferences.js');

const requester = (overrides = {}) => ({
  ageMin: 25,
  ageMax: 45,
  preferredStructures: [],
  preferredIntentions: [],
  ...overrides,
});

const candidate = (overrides = {}) => ({
  age: 32,
  relationshipStructure: 'Solo poly',
  intentionTags: ['Friendship', 'Dating'],
  ...overrides,
});

test('accepts a candidate inside the requested age range when optional preferences are empty', () => {
  assert.equal(candidateMatchesPreferences(requester(), candidate()), true);
});

test('rejects candidates outside the requested age range', () => {
  assert.equal(candidateMatchesPreferences(requester(), candidate({age: 24})), false);
  assert.equal(candidateMatchesPreferences(requester(), candidate({age: 46})), false);
});

test('requires a preferred relationship structure when structures are selected', () => {
  const preferences = requester({preferredStructures: ['Relationship anarchy', 'Solo poly']});
  assert.equal(candidateMatchesPreferences(preferences, candidate({relationshipStructure: 'Solo poly'})), true);
  assert.equal(candidateMatchesPreferences(preferences, candidate({relationshipStructure: 'Hierarchical poly'})), false);
});

test('requires at least one overlapping intention when intention preferences are selected', () => {
  const preferences = requester({preferredIntentions: ['Community', 'Long-term relationship']});
  assert.equal(candidateMatchesPreferences(preferences, candidate({intentionTags: ['Community']})), true);
  assert.equal(candidateMatchesPreferences(preferences, candidate({intentionTags: ['Friendship', 'Dating']})), false);
});

test('rejects invalid or underage candidate ages defensively', () => {
  assert.equal(candidateMatchesPreferences(requester(), candidate({age: 17})), false);
  assert.equal(candidateMatchesPreferences(requester(), candidate({age: 'not-a-number'})), false);
});

test('clamps malformed requester age preferences to adult bounds', () => {
  assert.equal(candidateMatchesPreferences(requester({ageMin: -50, ageMax: 999}), candidate({age: 90})), true);
});
