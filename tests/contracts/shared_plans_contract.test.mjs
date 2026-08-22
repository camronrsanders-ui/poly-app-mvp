import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const backend = read('functions/src/shared_plans.ts');
const fields = read('functions/src/shared_plan_fields.ts');
const entry = read('functions/src/entry.ts');
const accountDeletion = read('functions/src/index.ts');
const service = read('lib/services/shared_plans_service.dart');
const chat = read('lib/screens/messages/chat_screen.dart');
const rules = read('firestore.rules');

test('Plans stay behind trusted App Check callables and the active conversation boundary', () => {
  assert.match(
    entry,
    /createSharedPlan,[\s\S]*listSharedPlans,[\s\S]*updateSharedPlan,[\s\S]*cancelSharedPlan/,
  );
  assert.match(backend, /enforceAppCheck:\s*true/g);
  assert.match(backend, /assertActiveCompliantMember/);
  assert.match(backend, /conversation\.get\('active'\) !== true/);
  assert.match(backend, /collection\('blocks'\)/);
  assert.match(backend, /messageType:\s*'shared_plan'/);
});

test('Plan creation stays fail-closed until structured cards are approved', () => {
  assert.match(backend, /const SHARED_PLANS_CREATE_ENABLED = false/);
  assert.match(backend, /if \(!SHARED_PLANS_CREATE_ENABLED\)/);
  assert.doesNotMatch(chat, /Make (?:a )?plan/i);
});

test('Plans use a deliberately small manual model with no calendar/location automation', () => {
  assert.match(fields, /title/);
  assert.match(fields, /plannedForMs/);
  assert.match(fields, /placeLabel/);
  assert.match(fields, /note/);
  assert.match(fields, /calendarEventId/);
  assert.match(fields, /recommendedVenue/);
  assert.match(fields, /latitude/);
  assert.match(fields, /manual details only/);
});

test('only the creator can edit or cancel an existing plan', () => {
  assert.match(backend, /plan\.get\('senderUid'\) !== uid/);
  assert.match(backend, /Cancelled plans cannot be edited/);
  assert.match(backend, /planStatus:\s*'cancelled'/);
  assert.match(service, /httpsCallable\('updateSharedPlan'\)/);
  assert.match(service, /httpsCallable\('cancelSharedPlan'\)/);
});

test('Plans inherit message/account-deletion lifecycle instead of a parallel datastore', () => {
  assert.match(backend, /collection\('messages'\)\.doc\(\)/);
  assert.match(accountDeletion, /collection\('messages'\)\.where\('senderUid', '==', uid\)/);
  assert.doesNotMatch(backend, /collection\('shared_plans'\)/);
});

test('direct clients cannot manufacture structured plan records', () => {
  assert.match(rules, /request\.resource\.data\.messageType == 'text'/);
  assert.match(service, /httpsCallable\('createSharedPlan'\)/);
});
