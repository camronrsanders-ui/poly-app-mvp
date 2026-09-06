import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const profile = fs.readFileSync(path.join(root, 'lib/screens/profile/profile_screen.dart'), 'utf8');

test('Profile load has timeout, bounded transient retry, error state, and manual retry', () => {
  assert.match(profile, /Future<Map<String, dynamic>\?> _loadProfileWithRetry/);
  assert.match(profile, /attempt <= 3/);
  assert.match(profile, /\.getProfile\(uid\)[\s\S]*\.timeout\(const Duration\(seconds: 8\)\)/);
  assert.match(profile, /bool _shouldRetryProfileLoad/);
  assert.match(profile, /TimeoutException/);
  assert.match(profile, /'unavailable'/);
  assert.match(profile, /Duration\(milliseconds: attempt == 1 \? 300 : 700\)/);
  assert.match(profile, /Object\? _loadError/);
  assert.match(profile, /catch \(error\)[\s\S]*_loadError = error/);
  assert.match(profile, /Could not load your profile/);
  assert.match(profile, /Your profile was not changed/);
  assert.match(profile, /FilledButton\(onPressed: _load, child: const Text\('Try again'\)\)/);
});

test('Profile transient retry stays fail-closed for non-transient Firebase errors', () => {
  assert.match(profile, /error is FirebaseException/);
  assert.doesNotMatch(profile, /'permission-denied'[\s\S]*\.contains\(error\.code\)/);
  assert.match(profile, /attempt == 3 \|\| !_shouldRetryProfileLoad\(error\)\) rethrow/);
});

test('Profile loader sanitizes legacy values and keeps privacy fields fail-closed', () => {
  assert.match(profile, /String _choice/);
  assert.match(
    profile,
    /_openToConnections = data\['openToConnections'\] is bool[\s\S]*:\s*false;/,
  );
  assert.match(
    profile,
    /_choice\(\s*data\['profileVisibility'\],\s*_profileVisibilityOptions,\s*'hidden'\s*\)/,
  );
  assert.match(
    profile,
    /_choice\(\s*data\['mapVisibility'\],\s*_mapVisibilityOptions,\s*'private'\s*\)/,
  );
  assert.match(
    profile,
    /_profileVisibility = value \?\? 'hidden'/,
  );
  assert.match(
    profile,
    /_mapVisibility = value \?\? 'private'/,
  );
  assert.match(profile, /where\(connectionIntentionOptions\.contains\)/);
  assert.match(profile, /where\(relationshipStructureOptions\.contains\)/);
});
