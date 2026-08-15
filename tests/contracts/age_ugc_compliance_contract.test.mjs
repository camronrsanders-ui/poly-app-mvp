import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const read = (path) => fs.readFileSync(path, 'utf8');

const app = read('lib/app.dart');
const gate = read('lib/screens/compliance/compliance_gate_screen.dart');
const policy = read('lib/config/compliance_policy.dart');
const ugc = read('lib/services/ugc_text_policy.dart');
const messaging = read('lib/services/messaging_service.dart');
const profile = read('lib/services/profile_service.dart');
const circle = read('lib/services/relationship_card_service.dart');
const androidGradle = read('android/app/build.gradle.kts');
const androidActivity = read('android/app/src/main/kotlin/com/polycircle/app/MainActivity.kt');
const iosDelegate = read('ios/Runner/AppDelegate.swift');
const iosEntitlements = read('ios/Runner/Runner.entitlements');
const releaseGates = read('docs/release-gates.md');

test('session routes through current adult and policy compliance before onboarding', () => {
  assert.match(app, /accountHasCurrentCompliance\(account\)/);
  assert.match(app, /ComplianceGateScreen/);
  assert.match(gate, /ageOnDate\(birthDate, DateTime\.now\(\)\)/);
  assert.match(gate, /I am 18\+ and accept the Terms of Use/);
  assert.match(gate, /I accept the Community Guidelines/);
  assert.match(gate, /signal\.confirmsMinor/);
  assert.match(gate, /verificationRequired/);
  assert.match(gate, /signal\.regulatedRegion && !signal\.confirmsAdult/);
});

test('policy versions and adult assurance methods are explicit', () => {
  assert.match(policy, /currentTermsVersion = '2026-08-alpha-v1'/);
  assert.match(policy, /currentCommunityGuidelinesVersion = '2026-08-v1'/);
  assert.match(policy, /apple_declared_age_range/);
  assert.match(policy, /play_age_signals/);
  assert.match(policy, /self_attested_dob_fallback/);
});

test('Android integrates supported Play Age Signals and native Flutter bridge', () => {
  assert.match(androidGradle, /com\.google\.android\.play:age-signals:0\.0\.4/);
  assert.match(androidActivity, /com\.polycircle\.app\/age_assurance/);
  assert.match(androidActivity, /requestAgeSignalsAccess/);
  assert.match(androidActivity, /AgeSignalsStatus\.VERIFICATION_REQUIRED/);
  assert.match(androidActivity, /checkAgeSignals/);
});

test('iOS declares and invokes privacy-preserving declared age range', () => {
  assert.match(iosEntitlements, /com\.apple\.developer\.declared-age-range/);
  assert.match(iosDelegate, /canImport\(DeclaredAgeRange\)/);
  assert.match(iosDelegate, /requestAgeRange/);
  assert.match(iosDelegate, /ageGates: 18/);
  assert.match(iosDelegate, /declinedSharing/);
  assert.match(iosDelegate, /com\.polycircle\.app\/age_assurance/);
});

test('high-risk UGC prefilter is wired to normal posting surfaces but not reports', () => {
  assert.match(ugc, /_directViolentThreat/);
  assert.match(ugc, /_sexualSolicitationOfMinor/);
  assert.match(messaging, /UgcTextPolicy\.ensureAllowed\(trimmed\)/);
  assert.match(profile, /UgcTextPolicy\.ensureAllowedValues/);
  assert.match(circle, /UgcTextPolicy\.ensureAllowedValues/);
  assert.doesNotMatch(read('lib/services/safety_service.dart'), /UgcTextPolicy/);
});

test('release gates keep manual store and trusted moderation work explicit', () => {
  assert.match(releaseGates, /Restrict Minor Access/);
  assert.match(releaseGates, /trusted callable/i);
  assert.match(releaseGates, /Trusted backend moderation\/enforcement/);
  assert.match(releaseGates, /published support\/contact/i);
  assert.match(releaseGates, /final public legal document/i);
});
