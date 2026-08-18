import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const index = read('functions/src/index.ts');
const location = read('functions/src/discovery_location.ts');
const profileView = read('functions/src/profile_view_fields.ts');
const rules = read('firestore.rules');
const client = read('lib/services/discovery_service.dart');
const screen = read('lib/screens/discover/discover_screen.dart');
const androidManifest = read('android/app/src/main/AndroidManifest.xml');
const iosPlist = read('ios/Runner/Info.plist');

const discoverSection = index.match(
  /export const getDiscoverCandidates[\s\S]*?export const updateDiscoverLocation/,
)?.[0] ?? '';
const updateSection = index.match(
  /export const updateDiscoverLocation[\s\S]*?export const likeProfile/,
)?.[0] ?? '';

test('server enforces the saved radius in addition to all existing eligibility filters', () => {
  assert.match(discoverSection, /requesterProfile\.distanceRadius/);
  assert.match(discoverSection, /member_locations/);
  assert.match(discoverSection, /candidateMatchesPreferences/);
  assert.match(discoverSection, /passed\.has/);
  assert.match(discoverSection, /alreadyLiked\.has/);
  assert.match(discoverSection, /matchedBefore\.has/);
  assert.match(discoverSection, /blocked\.has/);
  assert.match(discoverSection, /distance > radiusMiles/);
  assert.match(discoverSection, /eligible\.sort/);
  assert.ok(
    discoverSection.indexOf('distance > radiusMiles')
      < discoverSection.lastIndexOf('toProfileView'),
    'Radius exclusion must happen before the client profile view is returned',
  );
});

test('the client cannot choose a radius in the candidate request payload', () => {
  const loadMethod = client.match(
    /final callable = _functions\.httpsCallable\('getDiscoverCandidates'\)[\s\S]*?\n  @override/,
  )?.[0] ?? '';
  assert.match(loadMethod, /\{'limit': limit\}/);
  assert.doesNotMatch(loadMethod, /distanceMiles|radiusMiles|latitude|longitude/);
  assert.match(screen, /saveDistanceMiles\(distanceMiles\)/);
});

test('precise member locations are Admin-only and absent from cross-user payloads', () => {
  assert.match(rules, /match \/member_locations\/\{uid\} \{ allow read, write: if false; \}/);
  assert.doesNotMatch(profileView, /latitude|longitude|geohash|accuracyMeters/);
  assert.doesNotMatch(discoverSection.match(/return \{[\s\S]*?\n    \};/)?.[0] ?? '', /latitude|longitude|geohash/);
  assert.match(updateSection, /return \{updated: true\}/);
  assert.doesNotMatch(updateSection.match(/return \{updated: true\}/)?.[0] ?? '', /latitude|longitude/);
});

test('location updates require App Check, active membership, validation, and rate limiting', () => {
  assert.match(updateSection, /enforceAppCheck: true/);
  assert.match(updateSection, /assertActive\(uid\)/);
  assert.match(updateSection, /consumeRateLimit\(uid, 'discover_location'/);
  assert.match(updateSection, /parseDiscoverLocationUpdate/);
  assert.match(location, /maximumLocationAccuracyMeters/);
  assert.match(location, /maximumObservationAgeMs/);
});

test('mobile permissions stay foreground-only with no background request', () => {
  assert.match(androidManifest, /ACCESS_COARSE_LOCATION/);
  assert.match(androidManifest, /ACCESS_FINE_LOCATION/);
  assert.doesNotMatch(androidManifest, /ACCESS_BACKGROUND_LOCATION/);
  assert.match(iosPlist, /NSLocationWhenInUseUsageDescription/);
  assert.doesNotMatch(iosPlist, /NSLocationAlways/);
});

test('account cleanup and recent-auth data access cover the private location record', () => {
  assert.match(index, /writer\.delete\(db\.collection\('member_locations'\)\.doc\(uid\)\)/);
  const dataAccess = read('functions/src/data_access.ts');
  assert.match(dataAccess, /discoverLocation: ownDiscoverLocation\(discoverLocation\)/);
  assert.match(dataAccess, /requireRecentAuth/);
});
