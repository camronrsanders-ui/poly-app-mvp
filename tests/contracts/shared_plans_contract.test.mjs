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
const plansScreen = read('lib/screens/messages/shared_plans_screen.dart');
const flags = read('lib/config/feature_flags.dart');
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
  assert.match(flags, /sharedPlansEnabled = false/);
  assert.match(
    chat,
    /if \(FeatureFlags\.sharedPlansEnabled\)[\s\S]{0,220}Key\('conversation-shared-plans'\)/,
  );
  assert.match(plansScreen, /if \(!FeatureFlags\.sharedPlansEnabled\) return/);
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
  assert.match(backend, /plan\.get\('planStatus'\) !== 'active'/);
  assert.match(backend, /Only active plans can be edited/);
  assert.match(backend, /const status = plan\.get\('planStatus'\)/);
  assert.match(backend, /if \(status === 'cancelled'\) return/);
  assert.match(backend, /if \(status !== 'active'\)/);
  assert.match(backend, /Only active plans can be cancelled/);
  assert.match(backend, /planStatus:\s*'cancelled'/);
  assert.match(service, /httpsCallable\('updateSharedPlan'\)/);
  assert.match(service, /httpsCallable\('cancelSharedPlan'\)/);
  assert.match(plansScreen, /plan\.creatorUid == uid/);
  assert.match(plansScreen, /final active = plan\.status == 'active'/);
  assert.match(plansScreen, /if \(mine && active\)/);
  assert.doesNotMatch(plansScreen, /if \(mine && !cancelled\)/);
});

test('plan list paths reject malformed and unknown-status stored records', () => {
  assert.match(
    backend,
    /const DISPLAYABLE_SHARED_PLAN_STATUSES = new Set\(\['active', 'cancelled'\]\)/,
  );
  assert.match(backend, /function isDisplayableSharedPlan/);
  assert.match(backend, /DISPLAYABLE_SHARED_PLAN_STATUSES\.has\(status\)/);
  assert.match(backend, /doc\.get\('plannedFor'\) instanceof Timestamp/);
  assert.match(
    backend,
    /snapshot\.docs\.filter\(isDisplayableSharedPlan\)\.map\(planResult\)/,
  );
  assert.match(
    service,
    /static const Set<String> _displayableStatuses = \{'active', 'cancelled'\}/,
  );
  assert.match(service, /plan\.creatorUid\.isNotEmpty/);
  assert.match(service, /plan\.title\.trim\(\)\.isNotEmpty/);
  assert.match(service, /plan\.plannedForMs != null/);
  assert.match(service, /_displayableStatuses\.contains\(plan\.status\)/);
});

test('plan timestamp decoding rejects fractional, negative, and out-of-range values', () => {
  assert.match(service, /static const int _maxSupportedEpochMillis = 253402300799999/);
  assert.match(service, /static int\? _trustedEpochMillis\(dynamic value\)/);
  assert.match(service, /value is! int \|\| value < 0 \|\| value > _maxSupportedEpochMillis/);
  assert.match(service, /plannedForMs:\s*_trustedEpochMillis\(data\['plannedForMs'\]\)/);
  assert.match(service, /cancelledAtMs:\s*_trustedEpochMillis\(data\['cancelledAtMs'\]\)/);
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

test('plan UI rejects past selections and stays inside the backend two-year boundary', () => {
  assert.match(plansScreen, /Duration\(days: 729\)/);
  assert.match(plansScreen, /if \(!plannedFor\.isAfter\(DateTime\.now\(\)\)\)/);
  assert.match(plansScreen, /Choose a future date and time/);
});

test('plan date and time display follows the member locale', () => {
  assert.match(plansScreen, /final localizations = MaterialLocalizations\.of\(context\)/);
  assert.match(plansScreen, /localizations\.formatMediumDate\(value\)/);
  assert.match(
    plansScreen,
    /localizations\.formatTimeOfDay\(TimeOfDay\.fromDateTime\(value\)\)/,
  );
  assert.doesNotMatch(plansScreen, /const months = \[/);
});

test('plan cards identify the creator without adding identity fields', () => {
  assert.match(service, /final String creatorUid/);
  assert.match(plansScreen, /plan\.creatorUid\.isEmpty/);
  assert.match(plansScreen, /Planned in this conversation/);
  assert.match(plansScreen, /Planned by you/);
  assert.match(plansScreen, /Planned by \$\{widget\.otherDisplayName\}/);
  assert.doesNotMatch(service, /creatorDisplayName/);
});

test('cancelled plan history uses the trusted server cancellation timestamp', () => {
  assert.match(backend, /cancelledAtMs:\s*timestampMillis\(doc\.get\('cancelledAt'\)\)/);
  assert.match(service, /final int\? cancelledAtMs/);
  assert.match(service, /cancelledAtMs:\s*_trustedEpochMillis\(data\['cancelledAtMs'\]\)/);
  assert.match(plansScreen, /final millis = plan\.cancelledAtMs/);
  assert.match(
    plansScreen,
    /MaterialLocalizations\.of\(\s*context,?\s*\)\.formatMediumDate\(cancelledAt\)/,
  );
  assert.match(plansScreen, /return 'Cancelled • \$date'/);
  assert.match(plansScreen, /if \(cancelledAt == null\) return 'Cancelled'/);
});
