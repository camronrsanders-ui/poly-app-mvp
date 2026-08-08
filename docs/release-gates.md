# Polycircle Release Gates

No feature is considered release-ready because the UI appears to work. Security, privacy, backend integrity, and negative tests are required.

## Gate 0 — Build health
Must pass in CI:
- `flutter pub get`
- `flutter analyze`
- Functions TypeScript build
- Firebase Firestore/Storage security tests

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

## Gate 2 — Closed beta
Required in addition to Gate 1:
- Firebase App Check configured and verified.
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

## Private Vault gate
`FeatureFlags.privateVaultEnabled` MUST remain false until GitHub issue #2 is closed and all of the following are verified:
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

## Merge policy
`restart-foundation` should not be merged to `main` until Gate 0 passes. Security-sensitive changes should land through reviewed pull requests once the project reaches active development on a computer/CI environment.
