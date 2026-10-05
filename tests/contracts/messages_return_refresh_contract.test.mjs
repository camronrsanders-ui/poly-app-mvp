import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');

const messages = fs.readFileSync(
  path.join(root, 'lib/screens/messages/messages_screen.dart'),
  'utf8',
);

const chat = fs.readFileSync(
  path.join(root, 'lib/screens/messages/chat_screen.dart'),
  'utf8',
);

test('Messages reloads trusted state after ChatScreen returns', () => {
  const push = messages.indexOf('await Navigator.of(context).push(');
  const mounted = messages.indexOf('if (!mounted) return;', push);
  const refresh = messages.indexOf('await _refresh();', mounted);

  assert.notEqual(push, -1);
  assert.ok(mounted > push);
  assert.ok(refresh > mounted);
});

test('Messages refresh never returns a Future from setState', () => {
  assert.doesNotMatch(
    messages,
    /setState\(\(\)\s*=>\s*_future\s*=/,
  );

  assert.match(
    messages,
    /setState\(\(\)\s*\{[\s\S]*?_future\s*=\s*next;[\s\S]*?\}\);/,
  );
});

test('Messages independently obtains trusted blocked-member state', () => {
  assert.match(messages, /SafetyService\(\)/);
  assert.match(messages, /_safety\.listBlockedUsers\(\)/);
  assert.match(messages, /blockedUids/);
  assert.match(messages, /blockedUids\.contains\(otherUid\)/);
});

test('Messages requires a usable active conversation reference', () => {
  assert.match(
    messages,
    /return conversationId\.isNotEmpty/,
  );
});

test('blocking completes before ChatScreen returns', () => {
  const block = chat.indexOf(
    'await _safety.blockUser(widget.otherUid);',
  );
  const pop = chat.indexOf(
    'Navigator.of(context).pop()',
    block,
  );

  assert.notEqual(block, -1);
  assert.ok(pop > block);
});
