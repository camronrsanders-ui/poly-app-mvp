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

test('Messages resolves participant and conversation list data through the trusted batched connection view', () => {
  assert.match(messagesScreen, /ConnectionService/);
  assert.match(messagesScreen, /loadConnections\(\)/);
  assert.match(connectionService, /httpsCallable\(['"]listMyConnections['"]\)/);
  assert.match(profileView, /const conversationRefs = records\.map\(\(\{match\}\) => db\.collection\(['"]conversations['"]\)\.doc\(match\.id\)\)/);
  assert.match(profileView, /db\.getAll\(\.\.\.conversationRefs\)/);
  assert.match(profileView, /conversationId:\s*conversationActive \? conversation\?\.id : null/);
});

test('client code does not issue a conversations collection listener', () => {
  assert.doesNotMatch(messagesScreen, /collection\(['"]conversations['"]\)/);
  assert.doesNotMatch(messagingService, /watchConversations/);
  assert.doesNotMatch(messagingService, /collection\(['"]conversations['"]\)[\s\S]*?snapshots\(\)/);
});

test('message send is atomic with the conversation activity update', () => {
  assert.match(messagingService, /final batch = _firestore\.batch\(\)/);
  assert.match(messagingService, /batch\.set\(messageRef/);
  assert.match(messagingService, /batch\.update\(conversationRef/);
  assert.match(messagingService, /await batch\.commit\(\)/);
});

test('full profile documents remain owner-only and active-account-only', () => {
  assert.match(
    rules,
    /match \/profiles\/\{uid\}[\s\S]*?allow read(?:, delete)?:\s*if isSelf\(uid\) && userIsActive\(uid\);/,
  );
});

test('message index matches the live chat ordering query', () => {
  assert.match(indexes, /"fieldPath": "conversationId", "order": "ASCENDING"/);
  assert.match(indexes, /"fieldPath": "createdAt", "order": "ASCENDING"/);
});
