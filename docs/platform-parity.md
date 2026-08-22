# Android / iOS Platform Parity

Polycircle is one Flutter product. Android and iOS must not evolve as separate feature branches, separate chat workstreams, or separate product implementations.

## Source of truth

- Primary development branch: `restart-foundation`.
- Shared product behavior belongs in Flutter unless a native platform API requires host-specific code.
- Android package/application ID: `com.polycircle.app`.
- iOS product bundle ID: `com.polycircle.app`.
- Local development uses Firebase project identifier `poly-circle-j5v6dy`, with Auth, Firestore, Functions, and Storage routed to local emulators by the guarded local launch scripts.
- Android toolchain carried forward from retired PR #7: Android Gradle Plugin `9.1.1`, Gradle `9.3.1`, Kotlin Android plugin `2.3.21`.

## Required parity rule

Whenever a change touches Android- or iOS-specific behavior, inspect the corresponding implementation on the other platform before considering the change complete.

A platform-only change is acceptable only when the underlying OS/API genuinely differs. The user-visible contract, security boundary, data shape, and Flutter-facing method/channel behavior must remain compatible unless a deliberate product decision documents otherwise.

At minimum, review both platforms for changes involving:

- permissions or privacy declarations;
- Flutter method channels and native payloads;
- Firebase configuration expectations;
- authentication or App Check;
- age assurance;
- location behavior;
- profile/media selection or delivery;
- deep links or external settings flows;
- app identity, signing, build settings, and release configuration;
- local emulator routing; and
- launch/build scripts.

## Cross-platform completion protocol

For meaningful shared or native-facing changes, use this order:

1. Make the product change once on `restart-foundation` (or on one short-lived branch that targets it), not once per device/chat.
2. Confirm the shared Flutter contract first; avoid OS-specific forks unless a native API requires them.
3. If native code changes on one platform, inspect the corresponding host code and permissions on the other platform in the same work cycle.
4. Run static/security/Firebase-rule tests and Flutter tests.
5. Require both the Android debug APK build and iOS simulator build to close green before calling the checkpoint verified or stacking the next risky change.
6. Record material parity decisions or exceptions here or in the durable project record. A closed side PR is not proof of completion; its intended behavior must be verified on the source-of-truth branch.

This protocol is specifically intended to prevent changes made while testing one device from silently failing to carry over to the other device.

## Automated parity gate

`tests/contracts/native_platform_parity_contract.test.mjs` protects the shared native contract. It currently verifies:

- permanent Android/iOS Polycircle app identity;
- age-assurance and Discover-location channel names;
- Flutter-facing native method names;
- compatible one-shot location result fields/statuses;
- foreground-only location permission posture;
- matching guarded Firebase emulator services and fixture coordinates; and
- fail-closed adult-only age-assurance behavior.

This contract runs inside the `contracts` job of Polycircle CI and must not be weakened merely to make a one-platform change pass.

Shared Moments and Shared Plans also follow a two-sided release gate: both are client-flagged OFF and server-gated OFF until their approved UI, staging, privacy, and device acceptance requirements pass. A modified client must not be able to enable an unfinished server capability.

## Build verification

Shared or native-facing work is not considered fully verified until CI confirms both:

1. Android debug APK build; and
2. iOS simulator debug build.

The same exact commit must receive both results. Passing Android from one commit and iOS from another is not a parity checkpoint.

Real-device validation remains a separate external-beta release gate for both platforms. Simulator/emulator success never substitutes for final physical-device acceptance.

## Consolidation checkpoint — 2026-08-22

PR #6 (`Connections meaningful moments redesign`) and PR #7 (`chore: validate Android toolchain 9.1.1`) are closed as superseded after their intended changes were verified on `restart-foundation`; they must not be merged back as stale branch state.

The unified branch retains the Connections-owned header, spotlight/meaningful-moments experience, trusted recency and connection actions, Discover handoff, and dedicated Connections contract from PR #6. It also retains AGP `9.1.1`, Gradle `9.3.1`, and Kotlin `2.3.21` from PR #7.

The shell has since added further shared navigation/refresh hardening while keeping Discover immersive and Connections/Circle responsible for their own headers. Conversation Space, Shared Moments scaffolding, and Shared Plans scaffolding are being built once in shared Flutter/trusted backend code and verified against both native build gates rather than through separate Android/iOS feature streams.

Future work should begin from `restart-foundation` so fixes do not become isolated in Android-only or iOS-only chat/work streams.
