import fs from 'node:fs';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const flags = fs.readFileSync('lib/config/feature_flags.dart', 'utf8');
const moments = fs.readFileSync('functions/src/shared_moments.ts', 'utf8');
const plans = fs.readFileSync('functions/src/shared_plans.ts', 'utf8');
const chat = fs.readFileSync('lib/screens/messages/chat_screen.dart', 'utf8');

test('unfinished structured message features are fail-closed on client and server', () => {
  assert.match(flags, /sharedMomentsEnabled = false/);
  assert.match(flags, /sharedPlansEnabled = false/);
  assert.match(moments, /const SHARED_MOMENTS_CREATE_ENABLED = false/);
  assert.match(plans, /const SHARED_PLANS_CREATE_ENABLED = false/);
});

test('unfinished structured message controls are not visible in chat', () => {
  assert.doesNotMatch(chat, /Shared Moments/i);
  assert.doesNotMatch(chat, /Save (?:a )?moment/i);
  assert.doesNotMatch(chat, /Make (?:a )?plan/i);
});
