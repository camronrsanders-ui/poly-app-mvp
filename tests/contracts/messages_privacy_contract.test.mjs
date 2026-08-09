import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const messagesScreen = read('lib/screens/messages/messages_screen.dart');
const connectionService = read('lib/services/connection_service.dart');
const rules = read('firestore.rules');

test('Messages never reads another users full profile document directly', () => {
  assert.doesNotMatch(messagesScreen, /collection\(['"]profiles['"]\)/);
  assert.doesNotMatch(messagesScreen, /FirebaseFirestore\.instance\.collection\(['"]profiles['"]\)/);
});

test('Messages resolves participant display data through the trusted connection view', () => {
  assert.match(messagesScreen, /ConnectionService/);
  assert.match(messagesScreen, /loadConnections\(\)/);
  assert.match(connectionService, /httpsCallable\(['"]listMyConnections['"]\)/);
});

test('full profile documents remain owner-only while Messages uses sanitized connection data', () => {
  assert.match(
    rules,
    /match \/profiles\/\{uid\}[\s\S]*?allow read, delete:\s*if isSelf\(uid\);/,
  );
});
