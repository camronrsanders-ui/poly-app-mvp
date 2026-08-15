# Polycircle Release Gates

No feature is considered release-ready because the UI appears to work. Security, privacy, backend integrity, and negative tests are required.

## Gate 0 — Build health
Must pass in CI:
- `flutter pub get`
- `flutter analyze`
- Flutter tests
- iOS simulator debug build regression
- Android debug APK build
- Functions TypeScript build and pure behavior tests
- client/backend security contract tests
- Firebase Firestore/Storage security tests, including inactive-account and moderation-internal boundaries
- development shell scripts parse cleanly

Before manual simulator/device test cycles, run the local development preflight:
- `bash tool/dev_preflight.sh`
- use `bash tool/dev_preflight.sh --full` when the emulator-backed Firestore/Storage adversarial suite should be included.

The one-command iOS local runner also selects Node 22 when available through nvm/Homebrew, validates local setup, refreshes approved branding when the exact source is available, checks stale emulator ports, starts matching-project Firebase emulators, seeds guarded local data, and launches Flutter in explicit emulator mode.

Local emulator success never substitutes for staging or real-device validation.

## Gate 1 — Internal alpha
Required:
- Firebase project correctly configured for iOS/Android.
- Email/password auth works end-to-end.
- Onboarding persists and routes correctly.
- Profile editing persists and profile load failures cannot silently overwrite stored data with blank defaults.
- Circle relationship-card CRUD/reorder works and malformed legacy enums cannot crash the editor.
- Discover uses trusted backend candidate retrieval with reciprocal private preferences, sanitized output, bounded reads, and no known N+1 block lookup.
- Like/match creation uses trusted backend transaction.
- Conversation creation uses trusted backend validation.
- Messaging authorization tested; failed sends preserve unsent draft text.
- Block/report tested across direct-ID access attempts.
- Blocked-member management works without restoring old matches/chats/private permissions on unblock.
- Inactive/paused/suspended/banned accounts fail closed across member data paths except the minimal self account record needed for routing/recovery.
- No unrestricted Firestore or Storage rules.
- Approved Polycircle launcher artwork is installed in both iOS and Android native launcher-icon sets and visually checked at launcher size.
- Launch/splash branding is checked separately from the launcher icon so correct in-app artwork cannot mask a stale native icon.
- The branded launcher-icon gate is incomplete until the exact approved artwork is confirmed on-device; do not substitute a generated/default icon merely to make the gate green.

## Gate 2 — Closed beta
Required in addition to Gate 1:
- Firebase App Check configured and verified on staging and real devices.
- Rate limits verified under emulator/staging tests.
- Crash/error reporting configured without sensitive payload logging.
- Android beta/release artifacts use a dedicated non-debug signing configuration; the current debug-key release fallback is local-smoke-only and must not be used for distributed builds.
- Account deletion/recovery passes end-to-end fault-injection tests: Firestore failure, BulkWriter failure, Storage cleanup failure, Auth deletion failure, retry after partial cleanup, and final minimal-tombstone cleanup.
- Privacy Policy and Terms drafts are completed with operator/jurisdiction/retention decisions and reviewed appropriately before publication.
- Community Guidelines reviewed/finalized.
- Moderator/admin/superadmin claim assignment and revocation validated on staging.
- Report moderation queue and protected profile-photo moderation queue validated operationally.
- Account suspension/ban/reinstatement validated, including privileged-target protection and permanent ban cleanup behavior.
- Operator-facing moderation workflow/UI or tightly controlled equivalent is operational; backend callables alone are insufficient.
- Image upload processing strips metadata through trusted re-encoding and validates content/type on real staging Storage.
- Dependency and secret scanning enabled/reviewed.
- Branch protection required for `main`.
- Production backup mechanism/retention/access controls chosen and a staging restore drill completed.
- Member data-access/export process finalized beyond the current bounded snapshot foundation.

## Gate 3 — External/public beta
Required in addition to Gate 2:
- End-to-end two-user acceptance journey passes on real iOS and Android devices using `docs/staging-acceptance-plan.md` or its reviewed successor.
- VoiceOver/TalkBack and large-text accessibility review completed; material blockers resolved or accepted explicitly.
- Performance/read-cost review measured on staging, including callable latency, Firestore operations, Functions runtime, and media bandwidth.
- Data retention policy finalized and implemented consistently across messages, reports, protected media, logs, backups, deletion tombstones, and inactive accounts.
- Abuse-response and security/privacy incident-response ownership assigned and procedures exercised.
- App-store privacy/safety disclosures completed accurately.
- No P0 security/safety issues open.

## Deferred paid-infrastructure work
A paid Firebase plan is not required for continued local implementation. Trusted callable development and automated security testing can continue with the guarded emulator workflow in `docs/local-development.md`.

The following remain release blockers and must not be marked complete based only on emulator results:
- deploy Cloud Functions to a real staging project;
- deploy and validate staging indexes/rules alongside those Functions;
- validate App Check enforcement against deployed callable endpoints;
- validate IAM/runtime service accounts and production API permissions;
- run protected-media signing/processing against real Cloud Storage;
- run account deletion and moderation end-to-end against staging data;
- perform real-device iOS/Android acceptance testing;
- configure/validate production backup/recovery;
- validate operational moderator access and audit behavior.

## Private Vault gate
`FeatureFlags.privateVaultEnabled` and the trusted server-side Private Vault gate MUST remain false until all of the following are verified:
- trusted upload authorization;
- quarantine/re-encode/metadata stripping;
- moderation/safety pipeline;
- per-item/per-recipient grants and revocation;
- block/unmatch/ban override grants;
- short-lived protected delivery, never permanent public URLs;
- reporting and moderator evidence workflow for sensitive media;
- account deletion cleanup;
- final evidence-removal/retention policy;
- age/policy/jurisdiction/app-store review;
- adversarial access-control tests;
- operational moderator access controls.

Closing an issue, having backend scaffolding, or making the UI visible is never sufficient to enable Private Vault.

## Merge policy
`restart-foundation` should not be merged to `main` until Gate 0 passes and the remaining release blockers are explicitly reviewed. Security-sensitive changes should land through reviewed pull requests. Keep PR #4 in draft while staging/payment-dependent and operational gates remain outstanding.
