import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const options = read('lib/config/discovery_options.dart');
const onboarding = read('lib/screens/onboarding/onboarding_screen.dart');
const profile = read('lib/screens/profile/profile_screen.dart');
const discover = read('lib/screens/discover/discover_screen.dart');

test('onboarding and profile settings share one relationship/intention option source', () => {
  assert.match(onboarding, /config\/discovery_options\.dart/);
  assert.match(profile, /config\/discovery_options\.dart/);
  assert.match(onboarding, /relationshipStructureOptions/);
  assert.match(onboarding, /connectionIntentionOptions/);
  assert.match(profile, /relationshipStructureOptions/);
  assert.match(profile, /connectionIntentionOptions/);
  assert.match(options, /const relationshipStructureOptions/);
  assert.match(options, /const connectionIntentionOptions/);
});

test('profile settings expose the private preferences enforced by discovery', () => {
  for (const field of [
    'ageMin',
    'ageMax',
    'distanceRadius',
    'preferredStructures',
    'preferredIntentions',
  ]) {
    assert.match(profile, new RegExp(`['\"]${field}['\"]`), `Profile settings are missing ${field}`);
  }
  assert.match(profile, /These preferences are private/);
});

test('Discover reload keeps setState synchronous after async actions', () => {
  assert.match(
    discover,
    /void _reload\(\) \{[\s\S]*?if \(!mounted \|\| _locationProblem != null\) return;[\s\S]*?unawaited\(_startFreshSession\(\)\);[\s\S]*?\}/,
  );
  assert.doesNotMatch(
    discover,
    /setState\(\(\)\s*=>\s*_discovery\.loadCandidates/,
    'A Future-returning expression callback makes Flutter throw after a successful Like/Pass.',
  );
});
