# Android development and test readiness

Android is the next native platform target for Polycircle. Keep this work on `restart-foundation`; do not merge PR #4 or modify `main` as part of native preparation.

## Current blocker

The Flutter package is cross-platform, and the client already selects Firebase App Check's Android debug provider in debug builds and Play Integrity in non-debug Android builds. However, the repository does not yet contain a committed `android/` Flutter host project, so Android cannot currently build or launch from this branch.

Do not treat Android as ready until all native files below are present and an automated Android debug build succeeds.

## Safe native-project generation

Use the Flutter SDK currently selected for the project and generate only the missing Android host from the repository root. Before accepting generated changes, make sure the package/application identifier is the intended Polycircle Android identifier and matches the Firebase Android app registration.

A typical regeneration command is:

```bash
flutter create --platforms=android .
```

Do not run broad project regeneration if it would overwrite an already-repaired native platform. Review the generated diff before committing it.

## Firebase Android configuration

Android requires a Firebase Android app registration whose package name exactly matches `applicationId`. Obtain the corresponding `google-services.json` from the Polycircle Firebase project and place it at:

```text
android/app/google-services.json
```

Do not copy configuration from an unrelated Firebase project. Do not place App Check debug tokens, service-account credentials, signing keys, or other secrets in the repository.

The Android Gradle app must apply the Google services plugin so native Firebase can initialize from `google-services.json`.

## App Check

Do not disable App Check for Android development. The Flutter client intentionally uses:

- `AndroidDebugProvider` for debug builds; and
- `AndroidPlayIntegrityProvider` for non-debug Android builds.

For emulator/device development, register the emitted App Check debug token in Firebase rather than weakening enforcement in source or rules.

Play Integrity must be validated on the eventual staging/release path; an emulator debug-token test is not release validation.

## Local Firebase emulator run

After the native Android host and Firebase configuration are committed, the preferred local test command is:

```bash
bash tool/run_android_local.sh
```

The runner refuses to start when `android/` or `android/app/google-services.json` is missing. It reuses the guarded local seed workflow and routes the Android emulator client to the host machine at `10.0.2.2` while keeping the seed process itself loopback-only.

With no argument, the runner uses `flutter devices --machine` and automatically selects the first connected Android target rather than relying on a display name such as `Android Emulator`, which varies between emulator images and machines. To target a specific Android device, pass either its exact Flutter device ID or exact Flutter device name:

```bash
bash tool/run_android_local.sh "emulator-5554"
```

Use `flutter devices` to inspect the available identifiers/names. The runner rejects a requested iOS/desktop/web target even if its name happens to match, so Android local routing cannot accidentally launch on the wrong platform.

## Build validation required before manual testing

Before calling Android test-ready, run at minimum:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Then run the standard Polycircle preflight and, when practical, the full emulator-backed security suite:

```bash
bash tool/dev_preflight.sh
bash tool/dev_preflight.sh --full
```

An Android build failure must be fixed before relying on emulator UI testing.

## Manual smoke-test checklist

On an Android emulator first, then a real Android device when available, verify:

1. launcher icon and app name;
2. app startup without native Firebase initialization errors;
3. App Check debug registration and protected callable behavior;
4. signup, login and onboarding;
5. Discover and profile detail;
6. Pass/Like/match behavior;
7. Connections and Messages;
8. Circle cards and trusted/redacted views;
9. image selection and profile-photo UI paths;
10. block, unmatch and report flows;
11. Safety Center and account settings;
12. account deletion against the appropriate test environment;
13. no Private Vault UI or backend bypass (Private Vault stays OFF).

Protected-media processing/delivery, deployed callable behavior, Play Integrity enforcement, account deletion against real data, and other staging-only paths remain release gates even after local Android testing passes.

## Release-signing boundary

Debug/emulator testing does not require production Play signing. Do not create or commit a production keystore merely to make local testing work. Release signing, Play Console registration, store listing/compliance, and production App Check/Play Integrity validation should be handled as a separate release-stage task after the debug Android host is reproducibly green.
