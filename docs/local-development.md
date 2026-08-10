# Local Firebase development without a paid Functions deployment

Polycircle can continue backend development on the Firebase Emulator Suite even when the Firebase project is not on a plan that supports Cloud Functions deployment.

## What stays local

The emulator workflow can run Authentication, Firestore, Cloud Functions, and Storage on the developer machine. It does not deploy or mutate production Cloud Functions. The Flutter app only connects to the emulators when both conditions are true:

1. the Flutter build is a debug build; and
2. `USE_FIREBASE_EMULATORS=true` is supplied as a Dart define.

The default remains production/staging Firebase configuration, so emulator routing cannot silently turn on in a release build. When emulator mode is active, the app displays a `LOCAL FIREBASE` debug banner.

## Recommended path before every simulator run

From the repository root, first activate the pinned Functions runtime:

```bash
nvm use
```

Then run the development preflight:

```bash
bash tool/dev_preflight.sh
```

The preflight checks the required tools/runtime versions, verifies important iOS Firebase settings when the native iOS directory is present, runs Flutter source analysis and tests, builds/tests the Functions package, and runs the client/backend contract suite. For the slower emulator-backed Firestore/Storage security suite, use:

```bash
bash tool/dev_preflight.sh --full
```

## One-command iOS local test run

After `nvm use`, the preferred simulator workflow is:

```bash
bash tool/run_ios_local.sh
```

That command runs the preflight, starts Authentication/Firestore/Functions/Storage emulators against the production-safe `demo-polycircle` project ID, seeds the local fixture data, launches the iPhone 17 simulator build with explicit emulator routing, and shuts the emulators down when the Flutter run exits.

To target another already-available Flutter device, pass its exact device name:

```bash
bash tool/run_ios_local.sh "iPhone 17 Pro"
```

The local fixture login is:

```text
Email: cam@local.polycircle.test
Password: LocalOnly123!
```

The fixture includes two Discover profiles, an existing connection, seeded chat messages, and a relationship card so Discover, Connections, Messages, and Circle can be exercised without a paid deployment.

## Manual emulator workflow

The steps below remain useful when the emulators need to stay running across multiple app launches.

### Node version

Cloud Functions target Node 22. If `nvm` is installed, run this from the repository root before installing Function dependencies:

```bash
nvm use
```

The repository `.nvmrc` pins Node 22. Do not develop the Functions package under Node 26 just because Homebrew installed it globally; npm will warn that it is outside the supported engine.

### Start the emulators

From the repository root:

```bash
cd functions
npm install
npm run build
cd ..
firebase emulators:start --project demo-polycircle --only auth,firestore,functions,storage
```

Leave that terminal running. The Emulator Suite UI is configured on port `4000`.

### Seed safe local test data

The seed script has two independent production guards: it requires both Auth and Firestore emulator host variables and it refuses any project ID that does not begin with `demo-`. It is intentionally safe to use only against Firebase emulators.

With the emulators already running, open another terminal and run:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
GCLOUD_PROJECT=demo-polycircle \
npm --prefix functions run seed:emulator
```

### Run the iOS Simulator against local Firebase

Open another terminal from the repository root:

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

## Launcher branding

The approved master artwork is pinned in `docs/branding.md` by exact source filename and SHA-256 so the dark Polycircle logo cannot be confused with the lighter alternative.

The Flutter/native launcher icon is separate from artwork shown inside the app. Replacing or generating a Polycircle logo does not automatically replace iOS `AppIcon.appiconset` or Android launcher resources.

On the development Mac, place the exact approved PNG in the project root, Downloads, or Desktop under its original filename, or pass its full path explicitly, then run:

```bash
bash tool/install_branding.sh
```

or:

```bash
bash tool/install_branding.sh "/full/path/to/a_logo_for_an_app_named_polycircle_is_displayed.png"
```

The installer verifies the approved SHA-256 before writing anything. It generates the iOS AppIcon sizes when the native iOS asset catalog is present and Android legacy launcher mipmaps when Android native resources are present. If Android adaptive-icon XML is detected, the script warns instead of pretending that adaptive branding has been visually validated.

After changing launcher icons, rebuild/reinstall the app. Simulator/device launchers can cache an old icon from a previously installed build.

## Security expectations

Local emulators are for development and automated testing only. Passing emulator tests does not replace staging validation of App Check, IAM, Cloud Functions deployment, indexes, Storage behavior, media processing, account deletion, moderation, or real-device behavior.

Protected-media workflows that depend on real Cloud Storage signing/processing should still be treated as staging release gates even if their Firestore/Functions logic is exercised locally.

## Before external beta

A real staging Firebase project must still have the required APIs/billing available for Cloud Functions deployment, and the release gates in `docs/release-gates.md` must pass before external beta distribution.
