import fs from 'node:fs';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const flags = fs.readFileSync('lib/config/feature_flags.dart', 'utf8');
const moments = fs.readFileSync('functions/src/shared_moments.ts', 'utf8');
const plans = fs.readFileSync('functions/src/shared_plans.ts', 'utf8');
const chat = fs.readFileSync('lib/screens/messages/chat_screen.dart', 'utf8');
const momentsScreen = fs.readFileSync(
  'lib/screens/messages/shared_moments_screen.dart',
  'utf8',
);
const plansScreen = fs.readFileSync(
  'lib/screens/messages/shared_plans_screen.dart',
  'utf8',
);

test('unfinished structured message features are fail-closed on client and server', () => {
  assert.match(flags, /sharedMomentsEnabled = false/);
  assert.match(flags, /sharedPlansEnabled = false/);
  assert.match(moments, /const SHARED_MOMENTS_CREATE_ENABLED = false/);
  assert.match(plans, /const SHARED_PLANS_CREATE_ENABLED = false/);
});

test('chat exposes structured-message navigation only inside explicit client gates', () => {
  assert.match(
    chat,
    /if \(FeatureFlags\.sharedMomentsEnabled\)[\s\S]{0,220}conversation-shared-moments/,
  );
  assert.match(
    chat,
    /if \(FeatureFlags\.sharedPlansEnabled\)[\s\S]{0,220}conversation-shared-plans/,
  );
  assert.doesNotMatch(chat, /FeatureFlags\.sharedMomentsEnabled\s*\?\s*true/);
  assert.doesNotMatch(chat, /FeatureFlags\.sharedPlansEnabled\s*\?\s*true/);
});

test('structured screens fail closed before loading trusted data', () => {
  assert.match(momentsScreen, /if \(FeatureFlags\.sharedMomentsEnabled\)[\s\S]{0,100}_reload\(\)/);
  assert.match(plansScreen, /if \(FeatureFlags\.sharedPlansEnabled\)[\s\S]{0,100}_reload\(\)/);
  assert.match(momentsScreen, /if \(!FeatureFlags\.sharedMomentsEnabled\) return/);
  assert.match(plansScreen, /if \(!FeatureFlags\.sharedPlansEnabled\) return/);
});
