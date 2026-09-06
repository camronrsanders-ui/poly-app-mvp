import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const shell = fs.readFileSync(path.join(root, 'lib/screens/main_shell.dart'), 'utf8');

test('main shell lazy-loads tabs instead of starting every network-backed screen at launch', () => {
  assert.match(shell, /late final List<Widget\?> _pages/);
  assert.match(shell, /_pages\[0\] = const DiscoverScreen\(\)/);
  assert.match(shell, /_pages\[value\] \?\?= _buildPage\(value\)/);
  assert.doesNotMatch(
    shell,
    /children:\s*const\s*\[\s*DiscoverScreen\(\),\s*ConnectionsScreen\(\),\s*CircleScreen\(\),\s*MessagesScreen\(\),\s*ProfileScreen\(\)/,
  );
});
