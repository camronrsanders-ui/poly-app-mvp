import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';

const preflight = fs.readFileSync('tool/dev_preflight.sh', 'utf8');

test('development preflight analyzes the same Flutter project scope as CI', () => {
  assert.match(preflight, /\nflutter analyze\n/);
  assert.doesNotMatch(preflight, /flutter analyze\s+lib(?:\s|$)/);
});
