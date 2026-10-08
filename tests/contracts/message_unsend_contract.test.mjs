import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const functionsSource = fs.readFileSync('functions/src/index.ts', 'utf8');
const messagingService = fs.readFileSync(
  'lib/services/messaging_service.dart',
  'utf8',
);
const chatScreen = fs.readFileSync(
  'lib/screens/messages/chat_screen.dart',
  'utf8',
);
const firestoreRules = fs.readFileSync('firestore.rules', 'utf8');
const sharedMomentPreview = fs.readFileSync(
  'functions/src/shared_moment_preview.ts',
  'utf8',
);

function between(source, startMarker, nextMarker = '\nexport const ') {
  const start = source.indexOf(startMarker);
  assert.notEqual(start, -1, `Missing ${startMarker}`);
  const end = source.indexOf(nextMarker, start + startMarker.length);
  return end === -1 ? source.slice(start) : source.slice(start, end);
}

const unsend = between(functionsSource, 'export const unsendMessage = onCall(');

test('unsend callable is App Check protected and active-member gated', () => {
  assert.match(unsend, /enforceAppCheck:\s*true/);
  assert.match(unsend, /const uid = requireUid\(request\.auth\);/);
  assert.match(unsend, /await assertActive\(uid\);/);
  assert.match(unsend, /consumeRateLimit\(uid,\s*'unsend_message'/);
});

test('unsend is sender-only and conversation-participant scoped', () => {
  assert.match(unsend, /message\.get\('senderUid'\)/);
  assert.match(unsend, /You can only unsend your own messages\./);
  assert.match(unsend, /participantUids\.includes\(uid\)/);
  assert.match(unsend, /You do not have access to this conversation\./);
});

test('unsend removes authored text but preserves a chronology tombstone', () => {
  assert.match(unsend, /message\.get\('isDeleted'\) === true/);
  assert.match(
    unsend,
    /tx\.update\(messageRef,\s*\{[\s\S]*?text:\s*''[\s\S]*?isDeleted:\s*true/,
  );
});

test('Flutter client routes unsend through the trusted callable', () => {
  assert.match(
    messagingService,
    /Future<void> unsendMessage\(String messageId\) async/,
  );
  assert.match(messagingService, /httpsCallable\('unsendMessage'\)/);
  assert.match(messagingService, /'messageId': normalizedMessageId/);
});

test('chat exposes confirmation and action only for non-deleted messages', () => {
  assert.match(chatScreen, /message-action-unsend/);
  assert.match(chatScreen, /Unsend this message\?/);
  assert.match(chatScreen, /Unsend message/);
  assert.match(chatScreen, /final canLongPress = !isDeleted;/);
  assert.match(chatScreen, /isDeleted\s*\?\s*'Message removed'/);
});

test('direct client mutation stays locked to read receipts', () => {
  assert.match(
    firestoreRules,
    /affectedKeys\(\)\.hasOnly\(\s*\[\s*'readBy'\s*\]\s*\)/,
  );
  assert.match(firestoreRules, /allow delete:\s*if false;/);
});

test('saved-message preview fails closed after source message is unsent', () => {
  assert.match(sharedMomentPreview, /data\.isDeleted === true/);
});
