import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const read = (path) => fs.readFileSync(path, 'utf8');

const pubspec = read('pubspec.yaml');
const config = read('lib/config/monetization_config.dart');
const entitlementService = read('lib/services/entitlement_service.dart');
const adPolicy = read('lib/services/ad_policy.dart');
const entitlementBackend = read('functions/src/monetization.ts');
const entitlementLogic = read('functions/src/monetization_entitlements.ts');
const functionsEntry = read('functions/src/entry.ts');
const docs = read('docs/monetization-architecture.md');

test('real billing and ad SDKs remain intentionally absent during architecture phase', () => {
  assert.match(config, /billingPurchaseFlowEnabled = false/);
  assert.match(config, /advertisingSdkEnabled = false/);
  assert.doesNotMatch(pubspec, /in_app_purchase:/);
  assert.doesNotMatch(pubspec, /google_mobile_ads:/);
});

test('debug subscription override cannot apply to release/profile builds', () => {
  assert.match(config, /if \(!kDebugMode\) return null/);
  assert.match(config, /POLYCIRCLE_DEBUG_SUBSCRIPTION_TIER/);
});

test('client reads entitlement through trusted callable and never writes billing state', () => {
  assert.match(entitlementService, /httpsCallable\('getMyEntitlements'\)/);
  assert.doesNotMatch(entitlementService, /FirebaseFirestore/);
  assert.doesNotMatch(entitlementService, /_billing_entitlements/);
});

test('trusted entitlement callable requires App Check and compliant membership', () => {
  assert.match(entitlementBackend, /getMyEntitlements = onCall/);
  assert.match(entitlementBackend, /enforceAppCheck: true/);
  assert.match(entitlementBackend, /assertActiveCompliantMember/);
  assert.match(entitlementBackend, /_billing_entitlements/);
  assert.match(functionsEntry, /getMyEntitlements/);
});

test('paid state requires trusted store verification and a live access deadline', () => {
  assert.match(entitlementLogic, /data\.storeVerified !== true/);
  assert.match(entitlementLogic, /app_store/);
  assert.match(entitlementLogic, /google_play/);
  assert.match(entitlementLogic, /accessUntilMs <= nowMs/);
  assert.match(entitlementLogic, /return freeEntitlement\('expired', source\)/);
});

test('entitlement response excludes raw billing evidence', () => {
  assert.doesNotMatch(entitlementLogic, /purchaseToken:/);
  assert.doesNotMatch(entitlementLogic, /originalTransactionId:/);
  assert.doesNotMatch(entitlementLogic, /receipt:/);
});

test('ads are restricted to a future Discover intermission and never safety/private surfaces', () => {
  assert.match(adPolicy, /return placement == AdPlacement\.discoverIntermission;/);
  for (const protectedPlacement of [
    'messages',
    'safetyCenter',
    'reportFlow',
    'blockFlow',
    'ageAssurance',
    'accountDeletion',
    'circle',
    'privateVault',
  ]) {
    assert.match(adPolicy, new RegExp(`\\b${protectedPlacement},`));
  }
  assert.doesNotMatch(
    adPolicy,
    /placement == AdPlacement\.(messages|safetyCenter|reportFlow|blockFlow|ageAssurance|accountDeletion|circle|privateVault)/,
  );
  assert.match(adPolicy, /if \(!privacyConsentAllowsAds\) return false/);
});

test('sensitive relationship and identity data is prohibited for ad targeting', () => {
  for (const field of [
    'sexual_orientation',
    'gender_identity',
    'relationship_structure',
    'circle_relationship_data',
    'profile_age',
    'precise_location',
    'race_or_ethnicity',
    'religion',
    'political_beliefs',
    'messages',
    'blocks',
    'reports',
    'age_assurance_metadata',
  ]) {
    assert.match(adPolicy, new RegExp(field));
  }
});

test('monetization plan explicitly protects safety and requires sandbox verification', () => {
  assert.match(docs, /must not become paid-only features/i);
  assert.match(docs, /blocking;/i);
  assert.match(docs, /reporting;/i);
  assert.match(docs, /account deletion;/i);
  assert.match(docs, /server-side purchase verification implemented/i);
  assert.match(docs, /Restore Purchases/i);
  assert.match(docs, /app-ads\.txt/i);
  assert.match(docs, /no production charges enabled/i);
});
