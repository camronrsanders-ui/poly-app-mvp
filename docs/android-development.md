# Android development and test readiness

Android is a supported native platform target for Polycircle. Keep this work on `restart-foundation`; do not merge PR #4 or modify `main` as part of native preparation.

## Current repository state

The Android Flutter host is committed, uses the permanent Polycircle application identity `com.polycircle.app`, includes the native Firebase/Google Services wiring, and is exercised by automated Android debug APK builds in verified CI checkpoints.

Android source/build readiness does not equal external-beta readiness. Remaining Android release work includes real physical-device validation, Play Integrity and App Check validation on the real release path, Play Console production configuration, production signing-key provisioning outside Git, and real staging validation of callable, protected-media, and account-deletion behavior.

## Native host recovery / regeneration

The committed Android host should normally be preserved. If it is damaged or deliberately regenerated, use the Flutter SDK currently selected for the project and regenerate only the Android platform from the repository root. Before accepting generated changes, make sure the package/application identifier is the intended Polycircle Android identifier and matches the Firebase Android app registration.

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

Debug/emulator testing does not require production Play signing. Do not create or commit a production keystore merely to make local testing work.

Android release builds now fail closed instead of falling back to the debug signing key. Real release signing is supplied outside Git with all four environment variables:

- `POLYCIRCLE_ANDROID_KEYSTORE_PATH`
- `POLYCIRCLE_ANDROID_KEYSTORE_PASSWORD`
- `POLYCIRCLE_ANDROID_KEY_ALIAS`
- `POLYCIRCLE_ANDROID_KEY_PASSWORD`

All four values must be present and non-blank, and the configured keystore path must point to an existing file when a release build runs. Missing or partial configuration stops the release build. Ordinary debug development and PR CI do not require release credentials.

The repository must never contain the production `.jks` / `.keystore` file or signing passwords. This configuration boundary does not create or provision a signing key.

There is no debug-signing fallback for the Android `release` build type. The existing `POLYCIRCLE_ANDROID_LOCAL_RELEASE_SMOKE` switch controls only the already-documented local cleartext behavior; it does not bypass release signing and does not authorize a distributable artifact.

Play Console registration, production signing-key provisioning, store listing/compliance, and production App Check / Play Integrity validation remain release-stage work.
