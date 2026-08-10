# Polycircle Release Gates

No feature is considered release-ready because the UI appears to work. Security, privacy, backend integrity, and negative tests are required.

## Gate 0 — Build health
Must pass in CI:
- `flutter pub get`
- `flutter analyze`
- Flutter tests
- Functions TypeScript build and pure behavior tests
- client/backend security contract tests
- Firebase Firestore/Storage security tests

Before manual simulator/device test cycles, run the local development preflight:
- `bash tool/dev_preflight.sh`
- use `bash tool/dev_preflight.sh --full` when the emulator-backed Firestore/Storage adversarial suite should be included.

Local development may use the Firebase Emulator Suite, but emulator success never substitutes for staging or real-device validation.

## Gate 1 — Internal alpha
Required:
- Firebase project correctly configured for iOS/Android.
- Email/password auth works end-to-end.
- Onboarding persists and routes correctly.
- Profile editing persists.
- Circle relationship-card CRUD works.
- Discover uses trusted backend candidate retrieval.
- Like/match creation uses trusted backend transaction.
- Conversation creation uses trusted backend validation.
- Messaging authorization tested.
- Block/report tested across direct-ID access attempts.
- No unrestricted Firestore or Storage rules.
- Approved Polycircle launcher artwork is installed in both iOS and Android native launcher-icon sets and visually checked at launcher size.
- Launch/splash branding is checked separately from the launcher icon so correct in-app artwork cannot mask a stale native icon.
- The branded launcher-icon gate is considered incomplete until the exact approved artwork is confirmed; do not substitute a generated/default icon simply to make the gate green.

## Gate 2 — Closed beta
Required in addition to Gate 1:
- Firebase App Check configured and verified on staging and real devices.
- Rate limits verified under emulator/staging tests.
- Crash/error reporting configured without sensitive payload logging.
- Account pause/delete flows implemented.
- Privacy Policy, Terms, and Community Guidelines drafted and reviewed.
- Moderation workflow exists for reports, suspensions, and bans.
- Image upload processing strips metadata and validates content/type.
- Dependency and secret scanning enabled.
- Branch protection required for `main`.
- Backup/recovery process documented.

## Gate 3 — External/public beta
Required in addition to Gate 2:
- End-to-end two-user acceptance journey passes on real iOS and Android devices.
- Accessibility review completed.
- Performance/read-cost review completed.
- Data retention policy finalized.
- Abuse-response and incident-response procedures documented.
- App-store privacy disclosures completed accurately.
- No P0 security/safety issues open.

## Deferred paid-infrastructure work
A paid Firebase plan is not required for continued local implementation. Trusted callable development and automated security testing can continue with the production-guarded emulator workflow in `docs/local-development.md`.

The following remain release blockers and must not be marked complete based only on emulator results:
- deploy Cloud Functions to a real staging project;
- deploy and validate staging indexes/rules alongside those Functions;
- validate App Check enforcement against deployed callable endpoints;
- validate IAM/runtime service accounts and production API permissions;
- run protected-media signing/processing against real Cloud Storage;
- run account deletion and moderation end-to-end against staging data;
- perform real-device iOS/Android acceptance testing.

## Private Vault gate
`FeatureFlags.privateVaultEnabled` and the trusted server-side Private Vault gate MUST remain false until all of the following are verified:
- trusted upload authorization;
- quarantine/re-encode/metadata stripping;
- moderation/safety pipeline;
- per-item/per-recipient grants and revocation;
- block/unmatch override grants;
- short-lived protected delivery, never permanent public URLs;
- reporting and moderation workflow for sensitive media;
- account deletion cleanup;
- age/policy/jurisdiction/app-store review;
- adversarial access-control tests.

Closing an issue or making the UI visible is never sufficient to enable Private Vault.

## Merge policy
`restart-foundation` should not be merged to `main` until Gate 0 passes and the remaining release blockers are explicitly reviewed. Security-sensitive changes should land through reviewed pull requests.
