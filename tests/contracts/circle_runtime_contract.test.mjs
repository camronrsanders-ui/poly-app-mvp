import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const circle = fs.readFileSync(path.join(root, 'lib/screens/circle/circle_screen.dart'), 'utf8');
const seed = fs.readFileSync(path.join(root, 'functions/scripts/seed_emulator.cjs'), 'utf8');

test('local Circle fixture uses values accepted by the editor', () => {
  const fixture = seed.match(/collection\('relationship_cards'\)[\s\S]*?\n  \}\);/)?.[0] ?? '';
  assert.match(fixture, /connectionType:\s*'romantic_partner'/);
  assert.match(fixture, /status:\s*'active'/);
  assert.match(fixture, /visibility:\s*'unnamed_public'/);
});

test('Circle editor falls back safely when legacy documents contain unknown enum values', () => {
  assert.match(circle, /String _safeChoice/);
  assert.match(circle, /_safeChoice\(existing\?\['connectionType'\], _connectionTypes, 'romantic_partner'\)/);
  assert.match(circle, /_safeChoice\(existing\?\['status'\], _statuses, 'active'\)/);
  assert.match(circle, /_safeChoice\(existing\?\['visibility'\], _visibilities, 'matches_only'\)/);
});

test('Circle rendering tolerates a malformed empty legacy label', () => {
  assert.match(circle, /final initial = label\.isEmpty \? '\?' : label\.characters\.first/);
});

test('Circle mutations surface failures instead of producing uncaught UI actions', () => {
  assert.match(circle, /Could not reorder your Circle right now/);
  assert.match(circle, /That Circle change could not be saved/);
  assert.match(circle, /Could not save this relationship/);
});

test('Circle modal does not own manually-disposed text controllers across route teardown', () => {
  assert.doesNotMatch(circle, /TextEditingController/);
  assert.match(circle, /TextFormField\(/);
  assert.match(circle, /initialValue: label/);
  assert.match(circle, /onChanged: \(value\) => label = value/);
});
