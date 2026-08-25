import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const connections = fs.readFileSync(
  'lib/screens/connections/connections_screen.dart',
  'utf8',
);

const shell = fs.readFileSync(
  'lib/screens/main_shell.dart',
  'utf8',
);

test('Connections owns a unique meaningful-moments experience', () => {
  assert.match(connections, /Nurture what matters\./);
  assert.match(connections, /SPOTLIGHT/);
  assert.match(connections, /Celebrate/);
  assert.match(connections, /Keep in touch/);
  assert.match(connections, /Moments keep connections strong\./);
  assert.match(connections, /Build your circle with intention/);
});

test('Connections preserves trusted connection actions', () => {
  assert.match(connections, /final connections = ConnectionService\(\);/);
  assert.match(
    connections,
    /_loadConnections = connections\.loadConnections;/,
  );
  assert.match(
    connections,
    /_endConnection = connections\.endConnection;/,
  );
  assert.match(connections, /final profileMedia = ProfileMediaService\(\);/);
  assert.match(
    connections,
    /_loadVisiblePhotos = profileMedia\.listVisiblePhotos;/,
  );
  assert.match(connections, /_loadConnections\(\)/);
  assert.match(connections, /await _endConnection\(otherUid\)/);
  assert.match(connections, /_loadVisiblePhotos\(uid\)/);
  assert.match(connections, /ensureConversation\(otherUid\)/);
  assert.match(connections, /showConnectAction: false/);
});

test('Connections avoids invented message content and uses trusted recency data', () => {
  assert.match(connections, /lastMessageAtMs/);
  assert.match(connections, /Your conversation is open/);
  assert.match(connections, /You chose each other/);
  assert.doesNotMatch(connections, /deep talked about purpose/);
});

test('Connections and Circle own their headers without regressing Discover shell styling', () => {
  assert.match(shell, /final discoverSelected = _index == 0;/);
  assert.match(
    shell,
    /final ownsItsHeader = discoverSelected \|\| _index == 1 \|\| _index == 2;/,
  );
  assert.match(
    shell,
    /ConnectionsScreen\(onFindPeople: \(\) => _selectTab\(0\)\)/,
  );
  assert.match(shell, /_MainNavigation\(/);
  assert.match(shell, /immersive: discoverSelected/);
  assert.match(shell, /discover-dark-navigation/);
});
