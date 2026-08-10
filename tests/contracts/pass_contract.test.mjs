import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const index = read('functions/src/index.ts');
const actions = read('functions/src/discovery_actions.ts');
const connectionService = read('lib/services/connection_service.dart');
const discoverScreen = read('lib/screens/discover/discover_screen.dart');
const detailScreen = read('lib/screens/profile/profile_detail_screen.dart');
const rules = read('firestore.rules');

test('Flutter Pass action has an App-Check-protected trusted backend export', () => {
  assert.match(connectionService, /httpsCallable\(['"]passProfile['"]\)/);
  assert.match(actions, /export const passProfile\b/);
  assert.match(actions, /enforceAppCheck:\s*true/);
  assert.match(index, /export \{passProfile\} from '.\/discovery_actions'/);
});

test('Pass attempts are rate-limited before target-specific account lookup', () => {
  const section = actions.match(/export const passProfile[\s\S]*/)?.[0] ?? '';
  const rateIndex = section.indexOf('consumeRateLimit(db, uid)');
  const targetLookupIndex = section.indexOf('tx.get(targetUserRef)');
  assert.ok(rateIndex >= 0 && targetLookupIndex >= 0 && rateIndex < targetLookupIndex,
    'Pass must charge the request budget before target lookup');
});

test('Pass is atomic with outgoing Like state and refuses current or former matches', () => {
  const section = actions.match(/export const passProfile[\s\S]*/)?.[0] ?? '';
  assert.match(section, /db\.runTransaction/);
  assert.match(section, /tx\.get\(likeRef\)/);
  assert.match(section, /tx\.get\(passRef\)/);
  assert.match(section, /tx\.get\(matchRef\)/);
  assert.match(section, /if \(existingMatch\.exists\)/);
  assert.match(section, /if \(existingLike\.exists\) tx\.delete\(likeRef\)/);
  assert.match(section, /tx\.set\(passRef/);
});

test('Like reads prior Pass in its transaction before deleting it', () => {
  const section = index.match(/export const likeProfile[\s\S]*?export const createConversation/)?.[0] ?? '';
  assert.match(section, /tx\.get\(passRef\)/);
  assert.match(section, /if \(existingPass\.exists\) tx\.delete\(passRef\)/);
});

test('Discover excludes persisted passes before returning sanitized profile views', () => {
  assert.match(index, /collection\('profile_passes'\)\.doc\(`\$\{uid\}_\$\{id\}`\)/);
  assert.match(index, /passed\.has\(doc\.id\)/);
  const passedCheck = index.indexOf('passed.has(doc.id)');
  const profileReturn = index.indexOf('output.push(toProfileView(doc.id, doc.data()))');
  assert.ok(passedCheck >= 0 && profileReturn >= 0 && passedCheck < profileReturn,
    'Pass filtering must occur before profile data is returned');
});

test('explicit Like can reverse the callers own prior Pass without exposing pass state', () => {
  assert.match(index, /const passRef = db\.collection\('profile_passes'\)\.doc\(`\$\{uid\}_\$\{toUid\}`\)/);
  assert.match(index, /tx\.delete\(passRef\)/);
});

test('Pass state and its rate limit are removed during account deletion', () => {
  assert.match(index, /profile_passes'\)\.where\('fromUid', '==', uid\)/);
  assert.match(index, /profile_passes'\)\.where\('toUid', '==', uid\)/);
  assert.match(index, /deleteDocs\(outgoingPasses\.docs\)/);
  assert.match(index, /deleteDocs\(incomingPasses\.docs\)/);
  assert.match(index, /'pass'/);
});

test('clients cannot directly inspect or manipulate Pass documents', () => {
  assert.match(rules, /match \/profile_passes\/\{passId\}[\s\S]*?allow read, write:\s*if false;/);
});

test('Discover exposes working View profile and Pass controls', () => {
  assert.match(discoverScreen, /ProfileDetailScreen\(profile: profile\)/);
  assert.match(discoverScreen, /_connections\.passUser\(uid\)/);
  assert.doesNotMatch(discoverScreen, /View profile'\)\),\s*$/m);
  assert.match(detailScreen, /class ProfileDetailScreen/);
});
