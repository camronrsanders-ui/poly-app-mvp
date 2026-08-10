import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const index = fs.readFileSync(path.join(root, 'functions/src/index.ts'), 'utf8');
const connectionsScreen = fs.readFileSync(
  path.join(root, 'lib/screens/connections/connections_screen.dart'),
  'utf8',
);

test('Discover excludes outgoing likes and any current or former match', () => {
  const section = index.match(/export const getDiscoverCandidates[\s\S]*?export const likeProfile/)?.[0] ?? '';
  assert.match(section, /outgoingLikeRefs/);
  assert.match(section, /alreadyLiked\.has\(doc\.id\)/);
  assert.match(section, /matchRefs/);
  assert.match(section, /matchedBefore\.has\(doc\.id\)/);
});

test('Like cannot silently restart an explicitly ended connection', () => {
  const section = index.match(/export const likeProfile[\s\S]*?export const createConversation/)?.[0] ?? '';
  assert.match(section, /existingMatch\.exists && existingMatch\.get\('active'\) !== true/);
  assert.match(section, /previous connection cannot be restarted/);
  assert.match(section, /tx\.create\(matchRef/);
});

test('opening an existing conversation does not rewrite chronology', () => {
  const section = index.match(/export const createConversation[\s\S]*?export const deleteMyAccount/)?.[0] ?? '';
  assert.match(section, /const existing = await tx\.get\(ref\)/);
  assert.match(section, /if \(!existing\.exists\)[\s\S]*tx\.create\(ref/);
  assert.match(section, /if \(existing\.get\('active'\) !== true\)/);

  const afterExistingCheck = section.split("if (existing.get('active') !== true)")[1] ?? '';
  assert.doesNotMatch(
    afterExistingCheck,
    /tx\.(?:set|update)\(ref[\s\S]*createdAt/,
    'Existing conversations must not have createdAt reset when opened.',
  );
});

test('Connections UI reuses a trusted existing conversation ID before calling creation', () => {
  const existingIndex = connectionsScreen.indexOf("person['conversationId']");
  const ensureIndex = connectionsScreen.indexOf('ensureConversation(otherUid)');
  assert.ok(existingIndex >= 0 && ensureIndex > existingIndex);
  assert.match(connectionsScreen, /if \(conversationId\.isEmpty\)/);
});
