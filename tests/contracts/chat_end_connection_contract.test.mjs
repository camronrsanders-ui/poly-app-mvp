import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');

const chat = fs.readFileSync(
  path.join(root, 'lib/screens/messages/chat_screen.dart'),
  'utf8',
);

const connectionService = fs.readFileSync(
  path.join(root, 'lib/services/connection_service.dart'),
  'utf8',
);

test('chat exposes a trusted End Connection action', () => {
  assert.match(chat, /ConnectionService\(\)/);
  assert.match(chat, /value: 'end'/);
  assert.match(chat, /Text\('End connection'\)/);
  assert.match(
    chat,
    /await _connections\.endConnection\(widget\.otherUid\)/,
  );
});

test('ending a connection requires explicit confirmation', () => {
  assert.match(
    chat,
    /End connection with \$\{widget\.otherDisplayName\}\?/,
  );
  assert.match(chat, /Keep connection/);
  assert.match(chat, /Ending a connection does not block the person/);
});

test('client uses the trusted endConnection callable', () => {
  assert.match(
    connectionService,
    /httpsCallable\('endConnection'\)/,
  );
  assert.match(
    connectionService,
    /result\.data\['ended'\] != true/,
  );
});

test('successful end returns from chat so Messages can reconcile', () => {
  const call = chat.indexOf(
    'await _connections.endConnection(widget.otherUid);',
  );
  const pop = chat.indexOf(
    'Navigator.of(context).pop();',
    call,
  );

  assert.notEqual(call, -1);
  assert.ok(pop > call);
});
