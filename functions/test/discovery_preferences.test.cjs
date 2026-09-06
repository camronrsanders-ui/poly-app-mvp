const test = require('node:test');
const assert = require('node:assert/strict');
const {candidateMatchesPreferences} = require('../lib/discovery_preferences.js');

const requester = (overrides = {}) => ({
  age: 30,
  relationshipStructure: 'Non-hierarchical poly',
  intentionTags: ['Friendship', 'Long-term relationship'],
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
  ageMin: 18,
  ageMax: 120,
  preferredStructures: [],
  preferredIntentions: [],
  ...overrides,
});

test('accepts two profiles when both sides preferences permit the other', () => {
  assert.equal(candidateMatchesPreferences(requester(), candidate()), true);
});

test('rejects candidates outside the requesters age range', () => {
  assert.equal(candidateMatchesPreferences(requester(), candidate({age: 24})), false);
  assert.equal(candidateMatchesPreferences(requester(), candidate({age: 46})), false);
});

test('requires a requester preferred relationship structure when structures are selected', () => {
  const preferences = requester({preferredStructures: ['Relationship anarchy', 'Solo poly']});
  assert.equal(candidateMatchesPreferences(preferences, candidate({relationshipStructure: 'Solo poly'})), true);
  assert.equal(candidateMatchesPreferences(preferences, candidate({relationshipStructure: 'Hierarchical poly'})), false);
});

test('requires at least one requester intention overlap when intentions are selected', () => {
  const preferences = requester({preferredIntentions: ['Community', 'Long-term relationship']});
  assert.equal(candidateMatchesPreferences(preferences, candidate({intentionTags: ['Community']})), true);
  assert.equal(candidateMatchesPreferences(preferences, candidate({intentionTags: ['Friendship', 'Dating']})), false);
});

test('respects the candidates age preference for the requester too', () => {
  assert.equal(candidateMatchesPreferences(requester({age: 30}), candidate({ageMin: 35, ageMax: 50})), false);
});

test('respects the candidates preferred relationship structures too', () => {
  assert.equal(candidateMatchesPreferences(
    requester({relationshipStructure: 'Non-hierarchical poly'}),
    candidate({preferredStructures: ['Solo poly']}),
  ), false);
});

test('respects the candidates preferred intentions too', () => {
  assert.equal(candidateMatchesPreferences(
    requester({intentionTags: ['Long-term relationship']}),
    candidate({preferredIntentions: ['Community']}),
  ), false);
});

test('rejects invalid or underage candidate ages defensively', () => {
  assert.equal(candidateMatchesPreferences(requester(), candidate({age: 17})), false);
  assert.equal(candidateMatchesPreferences(requester(), candidate({age: 'not-a-number'})), false);
});

test('rejects invalid or underage requester ages defensively', () => {
  assert.equal(candidateMatchesPreferences(requester({age: 17}), candidate()), false);
  assert.equal(candidateMatchesPreferences(requester({age: 'bad'}), candidate()), false);
});

test('clamps malformed requester age preferences to adult bounds', () => {
  assert.equal(candidateMatchesPreferences(requester({ageMin: -50, ageMax: 999}), candidate({age: 90})), true);
});
