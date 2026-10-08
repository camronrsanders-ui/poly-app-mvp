# Firebase App Check Rollout Guide

App Check is a required beta gate for Polycircle. The client code is configured to activate App Check after Firebase initialization. Debug builds use debug providers; release builds use Play Integrity on Android and App Attest with DeviceCheck fallback on Apple platforms.

## Why this matters
App Check helps reject requests from unauthorized/tampered clients. It complements Firebase Authentication, Firestore/Storage Security Rules, and trusted Cloud Functions; it does not replace any of them.

## Firebase Console setup
Do this only after the real Android/iOS Firebase apps exist and their bundle/application IDs are final enough for testing.

1. Open the real Polycircle Firebase project.
2. Go to Security > App Check.
3. Register the Android app with Play Integrity.
4. Register the iOS app with App Attest / DeviceCheck as appropriate.
5. Do not enable enforcement immediately.
6. Install a development build and verify App Check metrics show valid requests from the real app.
7. Verify callable Functions, Firestore, Storage, and Authentication flows still work.
8. Test a debug/emulator build using App Check debug tokens and keep debug tokens private.
9. Only after legitimate traffic is verified, enable enforcement progressively for the Firebase products Polycircle uses.
10. Re-run full signup/onboarding/discover/match/chat/block/report/account-deletion tests after enforcement.

## Client behavior
`lib/main.dart` activates App Check after `Firebase.initializeApp()` and before the app UI starts.

Debug builds:
- Android: debug provider.
- Apple: debug provider.

Release builds:
- Android: Play Integrity.
- Apple: App Attest with DeviceCheck fallback.

Never ship a hard-coded App Check debug token in the repository or application bundle.

## Cloud Functions
Security-sensitive callable Functions use `enforceAppCheck: true`. That includes trusted matching/conversation/safety/private-media operations. A valid signed-in account is still required separately.

## Enforcement checklist
Before external beta, verify:
- real iOS build produces valid App Check tokens;
- real Android build produces valid App Check tokens;
- debug builds work only with explicitly registered debug tokens where needed;
- Firestore access works with valid app + valid auth and still obeys Security Rules;
- Storage access works with valid app + valid auth and still obeys Storage Rules;
- callable Functions reject missing/invalid App Check where enforcement is configured;
- block, account status, match, conversation, and Private Vault authorization still work after App Check is enabled;
- App Check failures are handled with a user-safe error instead of exposing internal security details.

## Release rule
Do not enable public beta solely because App Check has been added to Flutter code. The Firebase Console registration, metrics validation, and enforcement tests must also be completed against the real Firebase project.
