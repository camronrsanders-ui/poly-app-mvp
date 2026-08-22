import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const chat = read('lib/screens/messages/chat_screen.dart');
const header = read('lib/widgets/conversation_space_header.dart');

test('Conversation Space keeps relationship identity compact and inside the app bar', () => {
  assert.match(chat, /title:\s*ConversationSpaceHeader\(/);
  assert.match(chat, /titleSpacing:\s*0/);
  assert.match(header, /conversation-space-identity/);
  assert.match(header, /height:\s*52/);
  assert.match(header, /Create a world together/);
  assert.doesNotMatch(header, /A private space for you and/);
});

test('Conversation Space preserves authoritative messaging and safety controls', () => {
  assert.match(chat, /watchMessages\(widget\.conversationId\)/);
  assert.match(chat, /sendMessage\(/);
  assert.match(chat, /markRead\(messageId\)/);
  assert.match(chat, /_report\(messageId:\s*doc\.id\)/);
  assert.match(chat, /blockUser\(widget\.otherUid\)/);
  assert.match(chat, /UgcPolicyViolation/);
  assert.match(chat, /conversation-message-composer/);
});

test('Moments and Plans stay absent until trusted lifecycle support exists', () => {
  const visibleUi = `${chat}\n${header}`;
  assert.doesNotMatch(visibleUi, /Shared Moments/i);
  assert.doesNotMatch(visibleUi, /Save (?:a )?moment/i);
  assert.doesNotMatch(visibleUi, /Make (?:a )?plan/i);
  assert.doesNotMatch(visibleUi, /Plans?\s*(?:button|tab|sheet)/i);
});
