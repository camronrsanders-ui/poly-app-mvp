# Polycircle Platform Sync Checkpoint — 2026-08-22

This checkpoint records the consolidation state after reconciling separate Android/iOS workstreams and retiring stale PR #6/#7 branches as sources of active development.

## Source of truth

- Repository: `camronrsanders-ui/poly-app-mvp`
- Active development branch: `restart-foundation`
- PR #4 (`Polycircle restart foundation`) remains Draft and must not be merged without explicit founder approval.
- `main` was not modified by this consolidation.
- PR #8 is an unrelated Bunt Cakes manager and is outside the Polycircle app workstream.

## Retired side PRs

### PR #6 — Connections meaningful moments redesign

Closed as superseded after verifying its intended behavior on `restart-foundation`. The unified branch retains:

- Connections-owned header and Safety Center access;
- spotlight / meaningful-moments presentation;
- trusted `lastMessageAtMs` recency behavior;
- Message, Profile, and Check in actions;
- Discover handoff / intentional-growth CTA;
- protected profile-media loading;
- trusted conversation/open/end-connection behavior; and
- `tests/contracts/connections_meaningful_moments_contract.test.mjs`.

The stale PR #6 branch must not be merged back into `restart-foundation`.

### PR #7 — Android toolchain validation

Closed as superseded after verifying the intended versions on `restart-foundation`:

- Android Gradle Plugin: `9.1.1`
- Gradle wrapper: `9.3.1`
- Kotlin Android plugin: `2.3.21`

The stale PR #7 branch must not be merged back into `restart-foundation`. These versions are a verified checkpoint, not permanent pins; future maintenance may upgrade them through the normal full parity gates.

## Android / iOS identity parity

Current permanent application identity:

- Android namespace/application ID: `com.polycircle.app`
- iOS Runner bundle ID: `com.polycircle.app`

Platform identity is aligned. Test bundle identifiers may append test-specific suffixes as expected.

## Messaging consolidation

Messages is one shared Flutter product path:

`Conversation Space -> intentionally saved Shared Moments -> structured Plans`

### Conversation Space

- Shared compact conversation identity/header experience is in the unified Flutter implementation.
- Existing message sending, read state, reporting, block/end behavior, UGC filtering, and protected profile-media access remain authoritative.

### Shared Moments foundation

- Reuses conversation `messages` lifecycle as `messageType: shared_moment`; no parallel shared datastore.
- App-Check-protected trusted callables enforce active/compliant participant and block boundaries.
- Direct client creation is denied.
- Note and human-readable place foundations exist.
- Saved-message moments retain only a validated `sourceMessageId`; the original message body is not duplicated.
- Precise coordinates are rejected.
- Photo is reserved but remains blocked until protected shared-media processing/moderation/delivery/removal/retention is complete.
- Server create gate remains OFF.
- Client UI remains OFF/not exposed.

### Shared Plans foundation

- Reuses conversation `messages` lifecycle as `messageType: shared_plan`; no parallel plan datastore.
- First model is deliberately manual: title, date/time, optional human-readable place label, optional note.
- Creator alone may edit/cancel.
- Cancellation is retained as history; cancelled plans cannot be edited.
- No calendar sync, venue recommendation engine, RSVP system, reminders, or precise coordinates.
- App-Check-protected trusted callables enforce active/compliant participant and block boundaries.
- Direct client creation is denied.
- Server create gate remains OFF.
- Client UI remains OFF/not exposed.

## Verified automated checkpoints

The synchronization process requires Android and iOS results from the same exact commit; passing different commits does not count as a parity checkpoint.

Completed green checkpoints before this record:

- Shared Moments foundation: commit `443c71b0cfdf104e1a40cc45e25309d80abd12b1`
  - Polycircle CI #1309: green
  - Dependency Audit #656: green
- Saved-message reference/privacy refinement: commit `9f20eb949fe9483360f14a06fd915a542a437346`
  - Polycircle CI #1311: green
  - Dependency Audit #658: green

Shared Plans checkpoint:

- commit `e34f1e9681192130754e9f3a322c2e532ea30913`
- Dependency Audit #660: green
- Polycircle CI #1313 must be fully green, including Android debug APK and iOS simulator build, before this checkpoint is treated as complete.

A follow-up gate-hardening commit may advance the branch after #1313 closes green; its own full CI/audit result then becomes the newest authoritative checkpoint.

## Permanent cross-platform completion rule

For meaningful shared or native-facing app changes:

1. Make the product change once from the `restart-foundation` source of truth (or a short-lived branch targeting it).
2. Keep shared behavior in Flutter unless the operating system genuinely requires native implementation.
3. When one native host changes, inspect the corresponding other host in the same work cycle.
4. Run Flutter, Functions, contract, and Firebase rules checks as applicable.
5. Require both Android debug APK and iOS simulator builds on the same exact commit before declaring the checkpoint verified or stacking the next risky change.
6. Keep physical-device Android and iOS acceptance as separate external-beta release gates.

A closed side PR or a successful one-platform build is not proof of cross-platform completion.

## Feature gates

The following unfinished/sensitive features remain fail-closed:

- Private Vault: client OFF + server OFF.
- Shared Moments: client OFF + server creation OFF.
- Shared Plans: client OFF + server creation OFF.

Do not enable these merely because scaffolding exists.

## Firebase / release state

The Firebase development situation remains contained but not release-resolved:

- local emulator development remains available without deploying paid Cloud Functions;
- iOS Firebase identity/configuration has been validated for `com.polycircle.app`;
- current release work still requires a real staging project/plan capable of Cloud Functions deployment;
- deployed Functions/rules/indexes, staging end-to-end Auth/Firestore/Storage behavior, and App Check enforcement against deployed endpoints remain required before external beta.

This checkpoint does not authorize enabling billing, deploying staging/production infrastructure, or weakening App Check/Firestore/Storage protections.

## Remaining external/manual acceptance gates

Automated parity is not a substitute for:

- physical Android device validation;
- physical iPhone validation;
- real staging profile-photo upload/moderation/protected-delivery testing;
- real-data account deletion and partial-failure/retry testing;
- final message/moment/plan/report/media/backup retention decisions;
- operational moderator/admin queues and response procedures;
- final Privacy Policy, Terms, Community Guidelines, legal/app-store compliance work; and
- Private Vault's dedicated moderation/privacy/retention/consent gates.

These remain release-readiness work rather than reasons to fork Android and iOS development again.
