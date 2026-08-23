import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const backend = read('functions/src/shared_moments.ts');
const fields = read('functions/src/shared_moment_fields.ts');
const entry = read('functions/src/entry.ts');
const accountDeletion = read('functions/src/index.ts');
const service = read('lib/services/shared_moments_service.dart');
const messaging = read('lib/services/messaging_service.dart');
const chat = read('lib/screens/messages/chat_screen.dart');
const momentsScreen = read('lib/screens/messages/shared_moments_screen.dart');
const flags = read('lib/config/feature_flags.dart');
const rules = read('firestore.rules');

test('Shared Moments stay behind trusted callables and active conversation checks', () => {
  assert.match(entry, /export \{createSharedMoment, listSharedMoments, deleteSharedMoment\} from '\.\/shared_moments';/);
  assert.match(backend, /enforceAppCheck:\s*true/g);
  assert.match(backend, /assertActiveCompliantMember/);
  assert.match(backend, /conversation\.get\('active'\) !== true/);
  assert.match(backend, /collection\('blocks'\)/);
  assert.match(backend, /messageType:\s*'shared_moment'/);
  assert.match(backend, /where\('messageType', '==', 'shared_moment'\)/);
});

test('Shared Moments creation stays server-gated until the product and photo lifecycle are ready', () => {
  assert.match(backend, /const SHARED_MOMENTS_CREATE_ENABLED = false/);
  assert.match(backend, /if \(!SHARED_MOMENTS_CREATE_ENABLED\)/);
  assert.match(backend, /Photo moments are not available until protected shared-media handling is ready/);
  assert.doesNotMatch(service, /createPhoto/);
});

test('Shared Moments read path fails closed for reserved and unknown kinds', () => {
  assert.match(
    backend,
    /const DISPLAYABLE_SHARED_MOMENT_KINDS = new Set\(\['note', 'place', 'message'\]\)/,
  );
  assert.match(
    backend,
    /snapshot\.docs\.filter\(\(doc\) =>[\s\S]{0,180}DISPLAYABLE_SHARED_MOMENT_KINDS\.has/,
  );
  assert.match(
    service,
    /static const Set<String> _displayableMomentKinds = \{[\s\S]{0,120}'note',[\s\S]{0,120}'place',[\s\S]{0,120}'message'/,
  );
  assert.match(service, /_displayableMomentKinds\.contains\(moment\.kind\)/);
});

test('Shared Moments inherit message lifecycle instead of a parallel datastore', () => {
  assert.match(backend, /collection\('messages'\)\.doc\(\)/);
  assert.match(backend, /senderUid:\s*uid/);
  assert.match(backend, /isDeleted:\s*false/);
  assert.match(accountDeletion, /collection\('messages'\)\.where\('senderUid', '==', uid\)/);
  assert.doesNotMatch(backend, /collection\('shared_moments'\)/);
});

test('saved-message moments keep only a source reference and ordinary chat filters them out', () => {
  assert.match(fields, /'message'/);
  assert.match(fields, /sourceMessageId/);
  assert.match(backend, /assertSavableSourceMessage/);
  assert.match(backend, /source\.get\('messageType'\) !== 'text'/);
  assert.match(backend, /sourceMessageId:\s*input\.sourceMessageId/);
  assert.doesNotMatch(backend, /sourceMessageText/);
  assert.match(service, /saveMessage\(/);
  assert.match(messaging, /where\('messageType', isEqualTo: 'text'\)/);
});

test('direct clients still cannot manufacture Shared Moments', () => {
  assert.match(rules, /request\.resource\.data\.messageType == 'text'/);
  assert.match(rules, /request\.resource\.data\.keys\(\)\.hasOnly\(\[[\s\S]*?'messageType', 'readBy'/);
  assert.match(service, /httpsCallable\('createSharedMoment'\)/);
  assert.match(service, /httpsCallable\('listSharedMoments'\)/);
  assert.match(service, /httpsCallable\('deleteSharedMoment'\)/);
});

test('moment foundation supports notes and places without precise location or raw photo paths', () => {
  assert.match(fields, /'note'/);
  assert.match(fields, /'place'/);
  assert.match(fields, /'photo'/);
  assert.match(fields, /latitude/);
  assert.match(fields, /longitude/);
  assert.match(fields, /geopoint/);
});

test('Shared Moments UI is present only behind the explicit client gate', () => {
  assert.match(flags, /sharedMomentsEnabled = false/);
  assert.match(
    chat,
    /if \(FeatureFlags\.sharedMomentsEnabled\)[\s\S]{0,220}Key\('conversation-shared-moments'\)/,
  );
  assert.match(momentsScreen, /if \(FeatureFlags\.sharedMomentsEnabled\)[\s\S]{0,100}_reload\(\)/);
  assert.match(momentsScreen, /if \(!FeatureFlags\.sharedMomentsEnabled\) return/);
  assert.match(momentsScreen, /if \(!FeatureFlags\.sharedMomentsEnabled\)[\s\S]{0,240}Shared Moments are still being prepared/);
});
