# Android / iOS Platform Parity

Polycircle is one Flutter product. Android and iOS must not evolve as separate feature branches or separate product implementations.

## Source of truth

- Primary development branch: `restart-foundation`.
- Shared product behavior belongs in Flutter unless a native platform API requires host-specific code.
- Android package/application ID: `com.polycircle.app`.
- iOS product bundle ID: `com.polycircle.app`.
- Local development uses Firebase project identifier `poly-circle-j5v6dy`, with Auth, Firestore, Functions, and Storage routed to local emulators by the guarded local launch scripts.

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

## Build verification

Shared or native-facing work is not considered fully verified until CI confirms both:

1. Android debug APK build; and
2. iOS simulator debug build.

Real-device validation remains a separate external-beta release gate for both platforms.

## Current consolidation checkpoint — 2026-08-21

The Connections meaningful-moments redesign from PR #6 and the validated Android toolchain update from PR #7 were reconciled into `restart-foundation` rather than force-merging stale branch state. The current shell keeps the newer immersive Discover navigation while allowing Connections and Circle to own their intended headers.

Future work should begin from `restart-foundation` so fixes do not become isolated in Android-only or iOS-only chat/work streams.
