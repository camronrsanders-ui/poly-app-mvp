import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const read = (path) => fs.readFileSync(path, 'utf8');

const app = read('lib/app.dart');
const gate = read('lib/screens/compliance/compliance_gate_screen.dart');
const policy = read('lib/config/compliance_policy.dart');
const complianceService = read('lib/services/compliance_service.dart');
const ugc = read('lib/services/ugc_text_policy.dart');
const messaging = read('lib/services/messaging_service.dart');
const profile = read('lib/services/profile_service.dart');
const circle = read('lib/services/relationship_card_service.dart');
const profileDetail = read('lib/screens/profile/profile_detail_screen.dart');
const chatScreen = read('lib/screens/messages/chat_screen.dart');
const safetyService = read('lib/services/safety_service.dart');
const safetyUi = read('lib/screens/safety/safety_center_screen.dart');
const safetyBackend = read('functions/src/safety.ts');
const moderationBackend = read('functions/src/moderation.ts');
const backendCompliance = read('functions/src/account_compliance.ts');
const complianceCallable = read('functions/src/compliance.ts');
const functionsEntry = read('functions/src/entry.ts');
const functionsPackage = read('functions/package.json');
const coreBackend = read('functions/src/index.ts');
const passBackend = read('functions/src/discovery_actions.ts');
const circleBackend = read('functions/src/circle_view.ts');
const connectionBackend = read('functions/src/profile_view.ts');
const profileAccessBackend = read('functions/src/profile_access.ts');
const profileMediaBackend = read('functions/src/profile_media.ts');
const profileMediaListingBackend = read('functions/src/profile_media_listing.ts');
const firestoreRules = read('firestore.rules');
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

test('adult policy approval is recorded through an App-Check-protected trusted callable', () => {
  assert.match(complianceService, /httpsCallable\('recordAdultPolicyAcceptance'\)/);
  assert.doesNotMatch(complianceService, /FirebaseFirestore/);
  assert.match(complianceCallable, /recordAdultPolicyAcceptance = onCall/);
  assert.match(complianceCallable, /enforceAppCheck: true/);
  assert.match(complianceCallable, /CURRENT_TERMS_VERSION/);
  assert.match(complianceCallable, /CURRENT_COMMUNITY_GUIDELINES_VERSION/);
  assert.match(complianceCallable, /method !== 'self_attested_dob_fallback'/);
  assert.match(complianceCallable, /signalStatus\.startsWith\('adult:'\)/);
  assert.match(functionsEntry, /recordAdultPolicyAcceptance/);
  assert.match(functionsPackage, /"main": "lib\/entry\.js"/);
  assert.match(firestoreRules, /backend-owned and can only be changed/);
  assert.match(firestoreRules, /affectedKeys\(\)\.hasOnly\(\[\s*'onboardingComplete', 'lastActiveAt'/);
});

test('Android integrates supported Play Age Signals 0.0.4 and native Flutter bridge', () => {
  assert.match(androidGradle, /com\.google\.android\.play:age-signals:0\.0\.4/);
  assert.match(androidActivity, /com\.polycircle\.app\/age_assurance/);
  assert.match(androidActivity, /requestAgeSignalsAccess/);
  assert.match(androidActivity, /AgeSignalsStatus\.VERIFICATION_REQUIRED/);
  assert.match(androidActivity, /checkAgeSignals/);
  assert.match(androidActivity, /ageResult\.ageRangeSource\(\)/);
  assert.match(androidActivity, /upper != null && upper < ADULT_AGE -> "minor"/);
  assert.match(androidActivity, /lower != null && lower >= ADULT_AGE -> "adult"/);
  assert.doesNotMatch(androidActivity, /AgeSignalsVerificationStatus/);
  assert.doesNotMatch(androidActivity, /ageResult\.userStatus\(\)/);
  assert.match(androidActivity, /"regulatedRegion" to true/);
});

test('iOS declares age range and fails closed when regulated eligibility is unknown', () => {
  assert.match(iosEntitlements, /com\.apple\.developer\.declared-age-range/);
  assert.match(iosDelegate, /canImport\(DeclaredAgeRange\)/);
  assert.match(iosDelegate, /requestAgeRange/);
  assert.match(iosDelegate, /ageGates: 18/);
  assert.match(iosDelegate, /declinedSharing/);
  assert.match(iosDelegate, /com\.polycircle\.app\/age_assurance/);
  assert.match(iosDelegate, /var regulatedRegion: Bool\?/);
  assert.match(iosDelegate, /"regulatedRegion": regulatedRegion \?\? true/);
});

test('high-risk UGC prefilter is wired to normal posting surfaces but not reports', () => {
  assert.match(ugc, /_directViolentThreat/);
  assert.match(ugc, /_sexualSolicitationOfMinor/);
  assert.match(messaging, /UgcTextPolicy\.ensureAllowed\(trimmed\)/);
  assert.match(profile, /UgcTextPolicy\.ensureAllowedValues/);
  assert.match(circle, /UgcTextPolicy\.ensureAllowedValues/);
  assert.doesNotMatch(safetyService, /UgcTextPolicy/);
});

test('Firestore independently rejects severe UGC on direct posting paths', () => {
  assert.match(firestoreRules, /function ugcTextAllowed\(text\)/);
  assert.match(firestoreRules, /ugcTextAllowed\(data\.bio\)/);
  assert.match(firestoreRules, /ugcTextAllowed\(data\.note\)/);
  assert.match(firestoreRules, /ugcTextAllowed\(request\.resource\.data\.text\)/);
});

test('core member callables use trusted adult and current-policy eligibility', () => {
  assert.match(backendCompliance, /CURRENT_TERMS_VERSION = '2026-08-alpha-v1'/);
  assert.match(backendCompliance, /CURRENT_COMMUNITY_GUIDELINES_VERSION = '2026-08-v1'/);
  assert.match(backendCompliance, /adultAccessApproved === true/);
  assert.match(coreBackend, /assertActiveCompliantMember/);
  assert.match(coreBackend, /isActiveCompliantMember/);
  assert.match(passBackend, /assertActiveCompliantMember/);
  assert.match(circleBackend, /assertActiveCompliantMember/);
  assert.match(connectionBackend, /assertActiveCompliantMember/);
  assert.match(safetyBackend, /assertActiveCompliantMember/);
  assert.match(profileAccessBackend, /assertActiveCompliantMember/);
  assert.match(profileMediaBackend, /assertActiveCompliantMember/);
  assert.match(profileMediaListingBackend, /assertActiveCompliantMember/);
});

test('reporting visibly includes child safety and threat categories', () => {
  assert.match(safetyBackend, /'child_safety'/);
  assert.match(safetyBackend, /'threats_violence'/);
  assert.match(safetyBackend, /'sexual_content'/);
  assert.match(safetyUi, /child-safety \/ underage/i);
  assert.match(safetyUi, /threats or violence/i);
});

test('profile reports identify the profile being reported', () => {
  assert.match(profileDetail, /final safety = _safety;/);
  assert.match(profileDetail, /return safety\.reportUser\(/);
  assert.match(profileDetail, /await _reportUser\(/);
  assert.match(profileDetail, /contentType: 'profile'/);
  assert.match(profileDetail, /contentId: _uid/);
  assert.match(safetyBackend, /Profile report does not match the reported account/);
});

test('message reports carry validated content context without copying message text', () => {
  assert.match(
    chatScreen,
    /final canLongPress =\s*!isDeleted &&\s*\(FeatureFlags\.sharedMomentsEnabled \|\| !isMine\)/,
  );
  assert.match(
    chatScreen,
    /if \(!FeatureFlags\.sharedMomentsEnabled\) \{[\s\S]{0,180}await _report\(messageId: messageId\)/,
  );
  assert.match(chatScreen, /contentType: reportingMessage \? 'message' : 'account'/);
  assert.match(safetyService, /Message reports require message context/);
  assert.match(safetyBackend, /String\(message\.get\('senderUid'\) \?\? ''\) !== reportedUid/);
  assert.match(safetyBackend, /participants\.includes\(reporterUid\)/);
  assert.match(safetyBackend, /participants\.includes\(reportedUid\)/);
  assert.match(moderationBackend, /contentType:/);
  assert.match(moderationBackend, /contentId:/);
  assert.match(moderationBackend, /conversationId:/);
  assert.doesNotMatch(safetyBackend, /message\.get\('text'\)/);
});

test('release gates keep manual store and trusted moderation work explicit', () => {
  assert.match(releaseGates, /Restrict Minor Access/);
  assert.match(releaseGates, /trusted callable/i);
  assert.match(releaseGates, /Trusted moderation\/enforcement/);
  assert.match(releaseGates, /published support\/contact/i);
  assert.match(releaseGates, /final public legal document/i);
});
