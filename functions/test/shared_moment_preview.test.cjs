const test = require('node:test');
const assert = require('node:assert/strict');
const {
  safeSharedMomentMessagePreview,
} = require('../lib/shared_moment_preview.js');

test('returns source text and author only for an available text message in the same conversation', () => {
  assert.deepEqual(safeSharedMomentMessagePreview({
    conversationId: 'conversation_1',
    messageType: 'text',
    isDeleted: false,
    text: 'This mattered to us.',
    senderUid: 'person_1',
  }, 'conversation_1'), {
    text: 'This mattered to us.',
    senderUid: 'person_1',
  });
});

test('does not reveal deleted, cross-conversation, non-text, or malformed sources', () => {
  assert.deepEqual(safeSharedMomentMessagePreview({
    conversationId: 'conversation_1',
    messageType: 'text',
    isDeleted: true,
    text: 'Deleted text',
    senderUid: 'person_1',
  }, 'conversation_1'), {text: '', senderUid: ''});

  assert.deepEqual(safeSharedMomentMessagePreview({
    conversationId: 'conversation_2',
    messageType: 'text',
    isDeleted: false,
    text: 'Wrong conversation',
    senderUid: 'person_1',
  }, 'conversation_1'), {text: '', senderUid: ''});

  assert.deepEqual(safeSharedMomentMessagePreview({
    conversationId: 'conversation_1',
    messageType: 'shared_moment',
    isDeleted: false,
    text: 'Not an ordinary message',
    senderUid: 'person_1',
  }, 'conversation_1'), {text: '', senderUid: ''});

  assert.deepEqual(safeSharedMomentMessagePreview({
    conversationId: 'conversation_1',
    messageType: 'text',
    isDeleted: false,
    text: 42,
    senderUid: 'person_1',
  }, 'conversation_1'), {text: '', senderUid: ''});

  assert.deepEqual(safeSharedMomentMessagePreview({
    conversationId: 'conversation_1',
    messageType: 'text',
    isDeleted: false,
    text: 'Missing author',
  }, 'conversation_1'), {text: '', senderUid: ''});

  assert.deepEqual(
    safeSharedMomentMessagePreview(undefined, 'conversation_1'),
    {text: '', senderUid: ''},
  );
});
