import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');
const index = read('functions/src/index.ts');
const pagination = read('functions/src/discovery_pagination.ts');
const client = read('lib/services/discovery_service.dart');
const screen = read('lib/screens/discover/discover_screen.dart');
const orbit = read('lib/widgets/discovery_orbit.dart');
const rules = read('firestore.rules');
const section = index.match(
  /export const getDiscoverCandidates[\s\S]*?export const updateDiscoverLocation/,
)?.[0] ?? '';

test('trusted Discover sessions page in opaque 15-person batches', () => {
  assert.match(pagination, /discoverPageSize = 15/);
  assert.match(pagination, /maximumDiscoverCandidatePool = 120/);
  assert.match(section, /_discover_sessions/);
  assert.match(section, /ownerUid: uid/);
  assert.match(section, /token: nextCursor/);
  assert.match(section, /candidateUids: eligible\.map/);
  assert.match(section, /nextIndex: page\.length/);
  assert.match(section, /expiresAt:/);
  assert.match(section, /sessionOwnerUid !== uid/);
  assert.match(section, /sessionToken !== cursor/);
  assert.match(section, /sessionRadiusMiles !== requester\.radiusMiles/);
  assert.match(section, /transaction\.get\(sessionRef\)/);
  assert.match(rules, /match \/_discover_sessions\/\{uid\} \{ allow read, write: if false; \}/);
});

test('every later page reuses the complete trusted eligibility pipeline', () => {
  const helper = index.match(
    /async function eligibleDiscoverCandidates[\s\S]*?return eligible;\n\}/,
  )?.[0] ?? '';
  for (const required of [
    /profileVisibility !== 'public'/,
    /openToConnections !== true/,
    /isActiveCompliantMember/,
    /passed\.has/,
    /alreadyLiked\.has/,
    /matchedBefore\.has/,
    /blocked\.has/,
    /candidateMatchesPreferences/,
    /candidateLocationAgeMs/,
    /distance > radiusMiles/,
  ]) assert.match(helper, required);
  assert.ok(
    section.split('eligibleDiscoverCandidates(').length >= 3,
    'first and subsequent pages must both call the same eligibility helper',
  );
  assert.match(section, /remainingUids/);
  assert.match(section, /stillEligible\.slice\(0, limit\)/);
});

test('cursor and response payloads never expose private location material', () => {
  assert.match(pagination, /\^\[A-Za-z0-9\]\{20\}\$/);
  assert.doesNotMatch(pagination, /latitude|longitude|geohash/);
  const returns = [...section.matchAll(/return \{[\s\S]*?\n\s*\};/g)]
    .map((match) => match[0])
    .join('\n');
  assert.doesNotMatch(returns, /latitude|longitude|geohash|accuracyMeters/);
});

test('client appends unique UIDs, prefetches three profiles ahead, and resets sessions', () => {
  assert.match(client, /const int discoverPageSize = 15/);
  assert.match(client, /if \(cursor != null\) 'cursor': cursor/);
  assert.match(screen, /_prefetchRemainingProfiles = 3/);
  assert.match(screen, /_sessionUids\.add\(uid\)/);
  assert.match(screen, /_appendPage\(page\)/);
  assert.match(screen, /_startFreshSession\(\)/);
  assert.match(screen, /_nextCursor = null/);
  assert.match(screen, /_maximumRetainedProfiles = 60/);
  assert.match(screen, /_maximumPhotoFutures = 20/);
  assert.match(orbit, /visibleFeedIndices/);
  assert.match(orbit, /onRequestMore/);
  assert.match(orbit, /hasMoreProfiles/);
});
