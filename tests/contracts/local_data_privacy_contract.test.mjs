import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const main = fs.readFileSync(path.join(root, 'lib/main.dart'), 'utf8');

test('native Polycircle disables persistent Firestore disk caching', () => {
  assert.match(main, /if \(!kIsWeb\)/);
  assert.match(main, /FirebaseFirestore\.instance\.settings = const Settings/);
  assert.match(main, /persistenceEnabled:\s*false/);
});

test('Firestore cache policy is applied before Firebase runtime routing and app launch', () => {
  const cacheIndex = main.indexOf('FirebaseFirestore.instance.settings');
  const runtimeIndex = main.indexOf('configureFirebaseRuntime()');
  const launchIndex = main.indexOf('runApp(const PolycircleApp())');
  assert.ok(cacheIndex >= 0 && runtimeIndex > cacheIndex && launchIndex > runtimeIndex);
});
