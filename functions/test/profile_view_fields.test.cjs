const test = require('node:test');
const assert = require('node:assert/strict');
const {toProfileView} = require('../lib/profile_view_fields.js');

test('trusted profile view exposes only display-safe fields', () => {
  const view = toProfileView('candidate-1', {
    displayName: 'Alex',
    age: 31,
    city: 'Cambridge',
    region: 'MA',
    bio: 'Hello',
    headline: 'Open and honest',
    genderIdentity: 'Nonbinary',
    pronouns: 'they/them',
    orientation: 'Queer',
    customIdentityTags: ['demisexual'],
    relationshipStructure: 'Relationship anarchy',
    relationshipStatus: 'Dating',
    partnered: true,
    intentionTags: ['Dating'],
    interests: ['Art'],
    lookingForNote: 'Clear communication',
    ageMin: 28,
    ageMax: 38,
    distanceRadius: 12,
    preferredStructures: ['Solo poly'],
    preferredIntentions: ['Dating'],
    profileVisibility: 'public',
    mapVisibility: 'hidden',
    internalModerationNote: 'never expose me',
    createdAt: {seconds: 1},
    updatedAt: {seconds: 2},
  });

  assert.deepEqual(view, {
    uid: 'candidate-1',
    displayName: 'Alex',
    age: 31,
    city: 'Cambridge',
    region: 'MA',
    bio: 'Hello',
    headline: 'Open and honest',
    genderIdentity: 'Nonbinary',
    pronouns: 'they/them',
    orientation: 'Queer',
    customIdentityTags: ['demisexual'],
    relationshipStructure: 'Relationship anarchy',
    relationshipStatus: 'Dating',
    partnered: true,
    intentionTags: ['Dating'],
    interests: ['Art'],
    lookingForNote: 'Clear communication',
  });
});

test('trusted profile view does not synthesize missing optional fields', () => {
  assert.deepEqual(toProfileView('candidate-2', {displayName: 'Riley'}), {
    uid: 'candidate-2',
    displayName: 'Riley',
  });
});

test('trusted profile view filters malformed legacy/admin values before cross-user delivery', () => {
  const view = toProfileView('candidate-3', {
    displayName: {nested: 'not a string'},
    age: 12,
    partnered: 'yes',
    intentionTags: ['Dating', {nested: true}, 'Dating', '', 7, 'Friendship'],
    interests: ['Art', null, 'Music'],
    customIdentityTags: [false, 'Queer'],
    headline: 'x'.repeat(500),
    preferredIntentions: ['must stay private'],
  });

  assert.equal(view.displayName, undefined);
  assert.equal(view.age, undefined);
  assert.equal(view.partnered, undefined);
  assert.deepEqual(view.intentionTags, ['Dating', 'Friendship']);
  assert.deepEqual(view.interests, ['Art', 'Music']);
  assert.deepEqual(view.customIdentityTags, ['Queer']);
  assert.equal(view.headline.length, 160);
  assert.equal(view.preferredIntentions, undefined);
});
