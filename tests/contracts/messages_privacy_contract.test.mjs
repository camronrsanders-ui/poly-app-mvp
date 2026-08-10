import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const messagesScreen = read('lib/screens/messages/messages_screen.dart');
const messagingService = read('lib/services/messaging_service.dart');
const connectionService = read('lib/services/connection_service.dart');
const profileView = read('functions/src/profile_view.ts');
const rules = read('firestore.rules');
const indexes = read('firestore.indexes.json');

test('Messages never reads another users full profile document directly', () => {
  assert.doesNotMatch(messagesScreen, /collection\(['"]profiles['"]\)/);
  assert.doesNotMatch(messagesScreen, /FirebaseFirestore\.instance\.collection\(['"]profiles['"]\)/);
});

test('Messages resolves participant and conversation list data through the trusted connection view', () => {
  assert.match(messagesScreen, /ConnectionService/);
  assert.match(messagesScreen, /loadConnections\(\)/);
  assert.match(connectionService, /httpsCallable\(['"]listMyConnections['"]\)/);
  assert.match(profileView, /collection\(['"]conversations['"]\)\.doc\(match\.id\)\.get\(\)/);
  assert.match(profileView, /conversationId:\s*conversationActive \? conversation\.id : null/);
});

test('client code does not issue a conversations collection listener', () => {
  assert.doesNotMatch(messagesScreen, /collection\(['"]conversations['"]\)/);
  assert.doesNotMatch(messagingService, /watchConversations/);
  assert.doesNotMatch(messagingService, /collection\(['"]conversations['"]\)[\s\S]*?snapshots\(\)/);
});

test('full profile documents remain owner-only while Messages uses sanitized connection data', () => {
  assert.match(
    rules,
    /match \/profiles\/\{uid\}[\s\S]*?allow read, delete:\s*if isSelf\(uid\);/,
  );
});

test('message index matches the live chat ordering query', () => {
  assert.match(indexes, /"fieldPath": "conversationId", "order": "ASCENDING"/);
  assert.match(indexes, /"fieldPath": "createdAt", "order": "ASCENDING"/);
});
