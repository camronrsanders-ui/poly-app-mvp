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
