import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const chat = read('lib/screens/messages/chat_screen.dart');
const service = read('lib/services/shared_moments_service.dart');
const backend = read('functions/src/shared_moments.ts');
const flags = read('lib/config/feature_flags.dart');

test('saved-message action remains hidden behind the client Shared Moments gate', () => {
  assert.match(flags, /sharedMomentsEnabled = false/);
  assert.match(
    chat,
    /if \(!FeatureFlags\.sharedMomentsEnabled\) \{[\s\S]{0,220}if \(isMine\) \{[\s\S]{0,160}_confirmUnsendMessage\(messageId\)[\s\S]{0,160}else \{[\s\S]{0,160}_report\(messageId: messageId\)/,
  );
  assert.match(chat, /key: const Key\('message-action-save-moment'\)/);
});

test('saving a message sends only its source reference and an optional user note', () => {
  assert.match(chat, /_sharedMoments\.saveMessage\([\s\S]{0,220}sourceMessageId: messageId,[\s\S]{0,100}note: noteText/);
  assert.doesNotMatch(
    chat,
    /_sharedMoments\.saveMessage\([\s\S]{0,260}\btext\s*:/,
  );
  assert.match(service, /'kind': 'message'/);
  assert.match(service, /'sourceMessageId': _requiredText\(sourceMessageId, 'message', 128\)/);
  assert.doesNotMatch(service, /sourceMessageText|messageBody/);
  assert.match(backend, /sourceMessageId:\s*input\.sourceMessageId/);
  assert.doesNotMatch(backend, /sourceMessageText|messageBody/);
});

test('deleted messages never expose message actions', () => {
  assert.match(chat, /final canLongPress = !isDeleted;/);
});

test('report remains available for received messages when Moments is disabled', () => {
  assert.match(
    chat,
    /if \(!FeatureFlags\.sharedMomentsEnabled\) \{[\s\S]{0,220}else \{[\s\S]{0,160}_report\(messageId: messageId\)/,
  );
  assert.match(chat, /if \(!isMine\)\s*ListTile\([\s\S]{0,220}message-action-report/);
});

test('unsend remains available for own messages when Moments is disabled', () => {
  assert.match(
    chat,
    /if \(!FeatureFlags\.sharedMomentsEnabled\) \{[\s\S]{0,220}if \(isMine\) \{[\s\S]{0,160}_confirmUnsendMessage\(messageId\)/,
  );
  assert.match(chat, /if \(isMine\)\s*ListTile\([\s\S]{0,260}message-action-unsend/);
});
