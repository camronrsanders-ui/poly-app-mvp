import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const index = read('functions/src/index.ts');
const circle = read('functions/src/circle_view.ts');
const rules = read('firestore.rules');

test('Circle profile view is exported through the trusted Functions entrypoint', () => {
  assert.match(circle, /export const getCircleForProfile\b/);
  assert.match(index, /export \{getCircleForProfile\} from '.\/circle_view'/);
  assert.match(circle, /enforceAppCheck:\s*true/);
});

test('global Circle visibility is enforced before card visibility', () => {
  assert.match(circle, /mapVisibility/);
  assert.match(circle, /mapVisibility === 'private'/);
  assert.match(circle, /mapVisibility === 'matches_only' && !matched/);
});

test('unnamed public cards redact optional names and free-text notes', () => {
  assert.match(circle, /safeCard\(card, visibility === 'unnamed_public'\)/);
  assert.match(circle, /!redactIdentity && typeof data\.displayNameOptional/);
  assert.match(circle, /!redactIdentity && typeof data\.note/);
});

test('full relationship-card documents are owner-only and active-account-only in Firestore', () => {
  assert.match(
    rules,
    /match \/relationship_cards\/\{cardId\}[\s\S]*?allow read:\s*if signedIn\(\) && userIsActive\(request\.auth\.uid\)[\s\S]*?&& resource\.data\.ownerUid == request\.auth\.uid;/,
  );
});

test('Circle view rate-limit state is cleaned during account deletion', () => {
  assert.match(circle, /action\s*=\s*'circle_view'/);
  assert.match(index, /'circle_view'/);
});
