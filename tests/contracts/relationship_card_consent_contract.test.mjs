import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const circle = read('functions/src/circle_view.ts');
const rules = read('firestore.rules');
const manager = read('lib/screens/circle/relationship_manager_screen.dart');

// H-10 (Step 2 PR 4): named relationship cards stay private until the
// person named can consent. Three layers: the read path withholds name
// and note from every non-owner (circle_privacy_contract pins the call
// shapes; functions/test/circle_card_projection.test.cjs covers the
// behavior matrix), the write rules stop new named exposure, and the
// editor is honest at the point of entry. These pins cover layers 2
// and 3 plus the render-private guarantee of layer 1.

test('the Circle read path never rewrites stored cards (render-private)', () => {
  const cardRead = circle.indexOf(".collection('relationship_cards')");
  assert.ok(cardRead !== -1);
  const readChain = circle.slice(cardRead, cardRead + 300);
  assert.match(readChain, /\.get\(\)/);
  assert.doesNotMatch(readChain, /\.(update|set|delete)\(/);
});

test('write rules block creating a named card at a non-private visibility', () => {
  assert.match(rules, /function cardExposesName\(data\)/);
  const helperStart = rules.indexOf('function cardExposesName');
  const helperEnd = rules.indexOf('\n    }', helperStart);
  const helper = rules.slice(helperStart, helperEnd);
  assert.match(helper, /data\.get\('displayNameOptional', ''\)/);
  assert.match(helper, /data\.get\('visibility', 'private'\) != 'private'/);
  assert.match(rules, /!cardExposesName\(request\.resource\.data\)/);
});

test('the named-card update rule is diff-aware so existing cards stay editable', () => {
  // Rules validate the full resulting document on every update, so a
  // naive named-must-be-private rule would freeze every pre-existing
  // named public card. The update gate must compare the name and the
  // visibility against the stored document and let untouched
  // grandfathered cards through (reorder, deactivate, label, note).
  assert.match(
    rules,
    /relationshipCardUpdateAllowed\(resource\.data, request\.resource\.data\)/,
  );
  assert.match(
    rules,
    /after\.get\('displayNameOptional', ''\)\s*==\s*before\.get\('displayNameOptional', ''\)/,
  );
  assert.match(
    rules,
    /after\.get\('visibility', 'private'\)\s*==\s*before\.get\('visibility', 'private'\)/,
  );
});

test('write rules deliberately do not gate the note field', () => {
  // A note can identify someone, but rules cannot tell an identifying
  // note from a legitimate one; the read path already withholds notes
  // from every non-owner, so the exposure helper must key on the name
  // and the visibility only.
  const helperStart = rules.indexOf('function cardExposesName');
  const helperEnd = rules.indexOf('\n    }', helperStart);
  const helper = rules.slice(helperStart, helperEnd);
  assert.doesNotMatch(helper, /note/);
});

test('the card editor forces named cards to private at open and at save', () => {
  assert.match(
    manager,
    /if \(displayName\.trim\(\)\.isNotEmpty\) \{[\s\S]*?visibility = 'private';/,
  );
  assert.match(
    manager,
    /String effectiveVisibility\(\) => nameEntered\(\) \? 'private' : visibility;/,
  );
  assert.match(manager, /visibility: effectiveVisibility\(\),/);
  assert.match(manager, /'visibility': effectiveVisibility\(\),/);
  assert.match(manager, /enabled: !nameEntered\(\) \|\| v == 'private',/);
});

test('the card editor explains the interim rule to owners', () => {
  assert.match(
    manager,
    /Names and notes on cards are now visible only to you until the other person confirms\./,
  );
  assert.match(
    manager,
    /Named cards stay private until the person can confirm the connection\./,
  );
  assert.match(
    manager,
    /Unnamed public: others see the relationship type, never a name\./,
  );
});
