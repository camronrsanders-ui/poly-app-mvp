import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {test} from 'node:test';

const root = path.resolve(import.meta.dirname, '../..');
const screensRoot = path.join(root, 'lib', 'screens');

// Lightweight source regression guard, not a substitute for tapping controls.
// A conditional null callback is valid for disabled/busy controls.
const callbacks = String.raw`\b(?:onPressed|onTap|onLongPress|onDoubleTap|onSelected|onChanged|onSubmitted|onEditingComplete|onReorder|onDismissed|onAccept)`;
const directEmpty = new RegExp(
  callbacks + String.raw`\s*:\s*(?:\([^(){};]*\)|[A-Za-z_$][\w$]*)\s*(?:async\s*)?\{\s*\}`,
  'gm',
);
const meaninglessArrow = new RegExp(
  callbacks + String.raw`\s*:\s*\([^{};]*\)\s*=>\s*(?:null|void\s+0)\s*[,;)]`,
  'gm',
);

function dartScreens(directory) {
  return fs.readdirSync(directory, {withFileTypes: true}).flatMap(entry => {
    const next = path.join(directory, entry.name);
    if (entry.isDirectory()) return dartScreens(next);
    return entry.isFile() && entry.name.endsWith('.dart') ? [next] : [];
  }).sort();
}

function inertHandlers(source) {
  return [...source.matchAll(directEmpty), ...source.matchAll(meaninglessArrow)]
    .map(match => ({
      line: source.slice(0, match.index).split('\n').length,
      snippet: match[0].replace(/\s+/g, ' ').trim(),
    }));
}

test('control guard catches literal empty and placeholder handlers', () => {
  for (const example of [
    'onPressed: () {},',
    'onTap: (_) async {\n\t},',
    'onChanged: (value) {\n},',
    'onPressed: () => null,',
  ]) {
    assert.ok(inertHandlers(example).length > 0, `Missed: ${example}`);
  }
  for (const example of [
    'onPressed: submitting ? null : save,',
    'onTap: () => openProfile(),',
    'onChanged: (value) { persist(value); },',
    'onChanged: (_) => setState(() {}),', // Rebuilds derived controller state.
    'onPressed: null,',
  ]) {
    assert.equal(inertHandlers(example).length, 0, `False positive: ${example}`);
  }
});

test('member-facing screen callbacks have no literal empty handlers', () => {
  const files = dartScreens(screensRoot);
  assert.ok(files.length >= 19, 'Expected the known screen inventory');
  const offenders = files.flatMap(file => inertHandlers(fs.readFileSync(file, 'utf8'))
    .map(hit => `${path.relative(root, file)}:${hit.line}: ${hit.snippet}`));
  assert.deepEqual(
    offenders,
    [],
    'Visible callback placeholders must have real actions or explicitly disabled states',
  );
});
