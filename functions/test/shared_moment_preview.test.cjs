const test = require('node:test');
const assert = require('node:assert/strict');
const {
  safeSharedMomentMessagePreview,
} = require('../lib/shared_moment_preview.js');

test('returns source text only for an available text message in the same conversation', () => {
  assert.equal(safeSharedMomentMessagePreview({
    conversationId: 'conversation_1',
    messageType: 'text',
    isDeleted: false,
    text: 'This mattered to us.',
  }, 'conversation_1'), 'This mattered to us.');
});

test('does not reveal deleted, cross-conversation, non-text, or malformed sources', () => {
  assert.equal(safeSharedMomentMessagePreview({
    conversationId: 'conversation_1',
    messageType: 'text',
    isDeleted: true,
    text: 'Deleted text',
  }, 'conversation_1'), '');

  assert.equal(safeSharedMomentMessagePreview({
    conversationId: 'conversation_2',
    messageType: 'text',
    isDeleted: false,
    text: 'Wrong conversation',
  }, 'conversation_1'), '');

  assert.equal(safeSharedMomentMessagePreview({
    conversationId: 'conversation_1',
    messageType: 'shared_moment',
    isDeleted: false,
    text: 'Not an ordinary message',
  }, 'conversation_1'), '');

  assert.equal(safeSharedMomentMessagePreview({
    conversationId: 'conversation_1',
    messageType: 'text',
    isDeleted: false,
    text: 42,
  }, 'conversation_1'), '');
  assert.equal(safeSharedMomentMessagePreview(undefined, 'conversation_1'), '');
});
