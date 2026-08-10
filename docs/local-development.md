# Local Firebase development without a paid Functions deployment

Polycircle can continue backend development on the Firebase Emulator Suite even when the Firebase project is not on a plan that supports Cloud Functions deployment.

## What stays local

The emulator workflow can run Authentication, Firestore, Cloud Functions, and Storage on the developer machine. It does not deploy or mutate production Cloud Functions. The Flutter app only connects to the emulators when both conditions are true:

1. the Flutter build is a debug build; and
2. `USE_FIREBASE_EMULATORS=true` is supplied as a Dart define.

The default remains production/staging Firebase configuration, so emulator routing cannot silently turn on in a release build.

## Start the emulators

From the repository root:

```bash
cd functions
npm install
npm run build
cd ..
firebase emulators:start --only auth,firestore,functions,storage
```

Leave that terminal running. The Emulator Suite UI is configured on port `4000`.

## Run the iOS Simulator against local Firebase

Open a second terminal from the repository root:

```bash
flutter run -d "iPhone 17" --dart-define=USE_FIREBASE_EMULATORS=true
```

The default emulator host is `127.0.0.1`, which is appropriate for the iOS Simulator on the same Mac.

If a different host is needed, override it explicitly:

```bash
flutter run \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

## Android Emulator

The Android Emulator normally reaches the host Mac at `10.0.2.2`:

```bash
flutter run \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

## App Check

Debug builds continue to use Firebase App Check debug providers. Do not disable App Check enforcement in source code simply to make local development easier. Keep any debug tokens private and never commit them.

## Security expectations

Local emulators are for development and automated testing only. Passing emulator tests does not replace staging validation of App Check, IAM, Cloud Functions deployment, indexes, Storage behavior, media processing, account deletion, moderation, or real-device behavior.

## Before external beta

A real staging Firebase project must still have the required APIs/billing available for Cloud Functions deployment, and the release gates in `docs/release-gates.md` must pass before external beta distribution.
