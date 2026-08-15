# Polycircle Release Gates

No feature is considered release-ready because the UI appears to work. Security, privacy, backend integrity, age assurance, UGC safety, and negative tests are required.

## Gate 0 — Build health
Must pass in CI:
- `flutter pub get`
- `flutter analyze`
- Flutter tests
- iOS simulator debug build regression
- Android debug APK build
- Functions TypeScript build and pure behavior tests
- client/backend security contract tests
- Firebase Firestore/Storage security tests, including inactive-account, adult-compliance, UGC-posting, and moderation-internal boundaries
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
- New accounts are routed through the adult-access/UGC-policy gate before onboarding/member access.
- Under-18 date-of-birth input is blocked; exact DOB is not persisted.
- Current Terms and Community Guidelines acceptance cannot be skipped in the normal app flow.
- A newly created account with `adultAccessApproved=false` cannot create/read member Firestore content until the approved compliance record is written.
- Platform age-assurance bridge failures are explicit and do not silently treat a confirmed minor or verification-required result as an adult.
- Onboarding persists and routes correctly.
- Profile editing persists and profile load failures cannot silently overwrite stored data with blank defaults.
- Circle relationship-card CRUD/reorder works and malformed legacy enums cannot crash the editor.
- Severe UGC text prefilter is exercised for profiles, messages, and Circle free text without blocking ordinary LGBTQ+/ENM identity discussion.
- Firestore independently rejects the same narrow severe UGC categories on direct profile/message/Circle writes so a modified client cannot bypass only the Flutter prefilter.
- Reports remain usable to describe violating content and are not blocked by the normal posting prefilter.
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
- Google Play production configuration selects 18+ as the only target age group and enables Restrict Minor Access for the dating/matchmaking app.
- Google Play Age Signals `SHARED`, `NOT_SHARED`, and `VERIFICATION_REQUIRED` paths are exercised on real Play-installed test builds/accounts.
- Apple Declared Age Range capability is enabled for the production App ID/signing profile and the 18+ range flow is exercised with Apple-supported sandbox/real-device testing.
- App Store Connect/Play Console age rating, social/UGC, target-audience, and safety declarations are reviewed against the shipping build.
- Every ordinary member-facing trusted callable that exposes or mutates community/member content enforces the approved adult/compliance state in addition to account activity. Deliberate privacy/exit paths such as own-data access and account deletion may remain available without accepting newer participation terms; privileged moderator/admin operations use their separate least-privilege security model.
- The temporary Firestore/backend missing-field migration allowance for legacy adult-compliance records is removed after migration/testing.
- Trusted moderation/enforcement exists for user-authored profile/message/public Circle text or an equivalent reviewed architecture. The Flutter prefilter and deterministic Firestore severe-content rules are defense-in-depth controls, not a substitute for contextual moderation and timely report handling.
- Account deletion/recovery passes end-to-end fault-injection tests: Firestore failure, BulkWriter failure, Storage cleanup failure, Auth deletion failure, retry after partial cleanup, and final minimal-tombstone cleanup.
- Privacy Policy and Terms are completed with operator/jurisdiction/retention/age-assurance decisions and reviewed appropriately before publication; the current pre-release Terms draft is not the final public legal document.
- Community Guidelines reviewed/finalized.
- A real published support/contact channel exists for users and app-store review; do not invent contact information only to satisfy a checklist.
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
- Data retention policy finalized and implemented consistently across messages, reports, protected media, logs, backups, deletion tombstones, inactive accounts, and age-assurance evidence.
- Abuse-response and security/privacy incident-response ownership assigned and procedures exercised, including timely handling of UGC reports.
- App-store privacy/safety/age/UGC disclosures completed accurately.
- Final Terms, Privacy Policy, Community Guidelines, and published support contact are live and match actual product behavior.
- No P0 security/safety issues open.

See `docs/app-store-age-ugc-compliance.md` for the implementation map, platform-specific manual configuration, and current unresolved compliance risks.

## Deferred paid-infrastructure work
A paid Firebase plan is not required for continued local implementation. Trusted callable development and automated security testing can continue with the guarded emulator workflow in `docs/local-development.md`.

The following remain release blockers and must not be marked complete based only on emulator results:
- deploy Cloud Functions to a real staging project;
- deploy and validate staging indexes/rules alongside those Functions;
- validate App Check enforcement against deployed callable endpoints;
- validate IAM/runtime service accounts and production API permissions;
- run protected-media signing/processing against real Cloud Storage;
- run account deletion and moderation end-to-end against staging data;
- perform real-device iOS/Android age-assurance and acceptance testing;
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
