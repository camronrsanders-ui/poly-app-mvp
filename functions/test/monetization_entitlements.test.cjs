const assert = require('node:assert/strict');
const test = require('node:test');

const {resolvePublicEntitlement} = require('../lib/monetization_entitlements');

test('missing entitlement is safely free', () => {
  assert.deepEqual(resolvePublicEntitlement(undefined, 1_000), {
    tier: 'free',
    status: 'none',
    source: 'none',
    accessUntilMs: null,
    capabilities: [],
    adsSuppressed: false,
  });
});

test('unverified paid-looking state cannot grant paid access', () => {
  const result = resolvePublicEntitlement({
    tier: 'premium',
    status: 'active',
    source: 'app_store',
    storeVerified: false,
    accessUntilMs: 10_000,
  }, 1_000);

  assert.equal(result.tier, 'free');
  assert.equal(result.adsSuppressed, false);
  assert.deepEqual(result.capabilities, []);
});

test('unsupported billing source cannot grant paid access', () => {
  const result = resolvePublicEntitlement({
    tier: 'plus',
    status: 'active',
    source: 'manual_client_claim',
    storeVerified: true,
    accessUntilMs: 10_000,
  }, 1_000);

  assert.equal(result.tier, 'free');
});

test('expired verified subscription falls back to free', () => {
  const result = resolvePublicEntitlement({
    tier: 'plus',
    status: 'active',
    source: 'google_play',
    storeVerified: true,
    accessUntilMs: 999,
  }, 1_000);

  assert.equal(result.tier, 'free');
  assert.equal(result.status, 'expired');
});

test('verified active plus subscription receives only plus capabilities', () => {
  const result = resolvePublicEntitlement({
    tier: 'plus',
    status: 'active',
    source: 'google_play',
    storeVerified: true,
    accessUntilMs: 10_000,
    purchaseToken: 'must-not-leak',
    originalTransactionId: 'must-not-leak',
  }, 1_000);

  assert.equal(result.tier, 'plus');
  assert.equal(result.status, 'active');
  assert.equal(result.adsSuppressed, true);
  assert.ok(result.capabilities.includes('advanced_discovery'));
  assert.ok(!result.capabilities.includes('advanced_circle'));
  assert.equal(Object.hasOwn(result, 'purchaseToken'), false);
  assert.equal(Object.hasOwn(result, 'originalTransactionId'), false);
});

test('verified premium grace period retains access until trusted access deadline', () => {
  const result = resolvePublicEntitlement({
    tier: 'premium',
    status: 'grace_period',
    source: 'app_store',
    storeVerified: true,
    accessUntilMs: 10_000,
  }, 1_000);

  assert.equal(result.tier, 'premium');
  assert.equal(result.status, 'grace_period');
  assert.ok(result.capabilities.includes('advanced_circle'));
});
