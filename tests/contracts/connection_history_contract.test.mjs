import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const index = fs.readFileSync(path.join(root, 'functions/src/index.ts'), 'utf8');
const safety = fs.readFileSync(path.join(root, 'functions/src/safety.ts'), 'utf8');
const connectionsScreen = fs.readFileSync(
  path.join(root, 'lib/screens/connections/connections_screen.dart'),
  'utf8',
);
const profileDetail = fs.readFileSync(
  path.join(root, 'lib/screens/profile/profile_detail_screen.dart'),
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

test('block and unmatch close chat without pretending a new message was sent', () => {
  const blockSection = safety.match(/export const blockUser[\s\S]*?export const unblockUser/)?.[0] ?? '';
  const unmatchSection = safety.match(/export const endConnection[\s\S]*$/)?.[0] ?? '';

  for (const section of [blockSection, unmatchSection]) {
    assert.match(section, /conversationRef/);
    assert.match(section, /active:\s*false/);
    assert.match(section, /endedAt:\s*FieldValue\.serverTimestamp\(\)/);
    assert.doesNotMatch(
      section,
      /lastMessageAt:\s*FieldValue\.serverTimestamp\(\)/,
      'Ending a connection must preserve the actual last-message timestamp.',
    );
  }
});

test('account deletion preserves last-message chronology and old end history', () => {
  const section = index.match(/export const deleteMyAccount[\s\S]*?export \{blockUser/)?.[0] ?? '';
  assert.match(section, /if \(doc\.get\('active'\) !== true\) continue/);
  assert.match(section, /endedReason:\s*'account_deleted'/);
  assert.doesNotMatch(
    section,
    /lastMessageAt:\s*FieldValue\.serverTimestamp\(\)/,
    'Account deletion must not create a fake last-message timestamp.',
  );
});

test('repeat unmatch does not overwrite the original ended history', () => {
  const section = safety.match(/export const endConnection[\s\S]*$/)?.[0] ?? '';
  const inactiveGuard = section.indexOf("if (match.get('active') !== true) return;");
  const matchWrite = section.indexOf('tx.set(matchRef');
  assert.ok(inactiveGuard >= 0 && matchWrite > inactiveGuard,
    'An already-ended match must return before rewriting end metadata.');
  assert.match(section, /if \(conversation\.exists && conversation\.get\('active'\) === true\)/);
});

test('Connections UI reuses a trusted existing conversation ID before calling creation', () => {
  const existingIndex = connectionsScreen.indexOf("person['conversationId']");
  const ensureIndex = connectionsScreen.indexOf('ensureConversation(otherUid)');
  assert.ok(existingIndex >= 0 && ensureIndex > existingIndex);
  assert.match(connectionsScreen, /if \(conversationId\.isEmpty\)/);
});

test('existing connections can reopen the trusted profile view without another Connect action', () => {
  assert.match(connectionsScreen, /ProfileDetailScreen/);
  assert.match(connectionsScreen, /showConnectAction:\s*false/);
  assert.match(connectionsScreen, /PopupMenuItem\(value:\s*'profile',\s*child:\s*Text\('View profile'\)\)/);
  assert.match(profileDetail, /this\.showConnectAction\s*=\s*true/);
  assert.match(profileDetail, /if \(widget\.showConnectAction\)/);
});
