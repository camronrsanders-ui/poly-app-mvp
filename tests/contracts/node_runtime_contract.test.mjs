import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const helper = fs.readFileSync(path.join(root, 'tool/ensure_node22.sh'), 'utf8');
const preflight = fs.readFileSync(path.join(root, 'tool/dev_preflight.sh'), 'utf8');
const runner = fs.readFileSync(path.join(root, 'tool/run_ios_local.sh'), 'utf8');

test('Node runtime helper prefers an existing nvm or Homebrew Node 22 installation', () => {
  assert.match(helper, /\.nvm\/nvm\.sh/);
  assert.match(helper, /nvm use 22/);
  assert.match(helper, /brew --prefix node@22/);
  assert.match(helper, /export PATH=/);
  assert.match(helper, /Node 22 is required for Polycircle Functions/);
});

test('preflight and one-command runner both source Node 22 in their own shell environments', () => {
  assert.match(preflight, /source "\$ROOT_DIR\/tool\/ensure_node22\.sh"/);
  assert.match(runner, /source "\$ROOT_DIR\/tool\/ensure_node22\.sh"/);
});
