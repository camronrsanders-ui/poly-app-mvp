import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const profile = fs.readFileSync(path.join(root, 'lib/screens/profile/profile_screen.dart'), 'utf8');

test('Profile load has timeout, error state, and retry instead of falling into an editable blank form', () => {
  assert.match(profile, /\.getProfile\(uid\)\.timeout\(const Duration\(seconds: 10\)\)/);
  assert.match(profile, /Object\? _loadError/);
  assert.match(profile, /catch \(error\)[\s\S]*_loadError = error/);
  assert.match(profile, /Could not load your profile/);
  assert.match(profile, /Your profile was not changed/);
  assert.match(profile, /FilledButton\(onPressed: _load, child: const Text\('Try again'\)\)/);
});

test('Profile loader sanitizes legacy dropdown/list values before widget construction', () => {
  assert.match(profile, /String _choice/);
  assert.match(profile, /_choice\(data\['profileVisibility'\], _profileVisibilityOptions, 'public'\)/);
  assert.match(profile, /_choice\(data\['mapVisibility'\], _mapVisibilityOptions, 'matches_only'\)/);
  assert.match(profile, /where\(connectionIntentionOptions\.contains\)/);
  assert.match(profile, /where\(relationshipStructureOptions\.contains\)/);
});
