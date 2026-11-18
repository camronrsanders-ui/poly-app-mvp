import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const onboarding = read('lib/screens/onboarding/onboarding_screen.dart');

test('onboarding never hard-codes a published or open profile in the save map', () => {
  // Product review 2026-11-17, finding H-7: onboarding silently published
  // every new profile. The save map must carry the member's choices, never
  // an open literal.
  assert.doesNotMatch(onboarding, /'profileVisibility':\s*'public'/);
  assert.doesNotMatch(onboarding, /'profileVisibility':\s*'matches_only'/);
  assert.doesNotMatch(onboarding, /'openToConnections':\s*true/);
  assert.doesNotMatch(onboarding, /'mapVisibility':\s*'matches_only'/);
  assert.doesNotMatch(onboarding, /'mapVisibility':\s*'public'/);
});

test('onboarding visibility state starts at the fail-closed defaults', () => {
  // The same defaults the profile model and editor already use: a new
  // member is hidden, not open, and their Circle view is private until
  // they opt in (Step 2 design pass, Decision 6a).
  assert.match(onboarding, /bool _openToConnections = false;/);
  assert.match(onboarding, /String _profileVisibility = 'hidden';/);
  assert.match(onboarding, /String _mapVisibility = 'private';/);
});

test('onboarding persists the visibility choices the member made', () => {
  assert.match(onboarding, /'openToConnections': _openToConnections,/);
  assert.match(onboarding, /'profileVisibility': _profileVisibility,/);
  assert.match(onboarding, /'mapVisibility': _mapVisibility,/);
});

test('onboarding asks who can see you with the profile editor labels', () => {
  // One vocabulary everywhere: the visibility step reuses the editor's
  // exact option labels instead of inventing a second set of words.
  assert.match(onboarding, /title: 'Who can see you\?',/);
  assert.match(onboarding, /labelText: 'Profile visibility'/);
  assert.match(onboarding, /Text\('Public to signed-in members'\)/);
  assert.match(onboarding, /Text\('Hidden'\)/);
  assert.match(onboarding, /labelText: 'Circle visibility'/);
  assert.match(onboarding, /Text\('Private'\)/);
  assert.match(onboarding, /title: const Text\('Open to new connections'\)/);
  // The switch copy must not repeat the editor's implication that the
  // switch alone controls Discover: both conditions are named.
  assert.match(
    onboarding,
    /You appear in Discover only when your profile is Public and this is on\./,
  );
});
