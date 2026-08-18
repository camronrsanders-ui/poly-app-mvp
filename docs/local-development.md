# Local Firebase development without a paid Functions deployment

Polycircle can continue backend development on the Firebase Emulator Suite even when the Firebase project is not on a plan that supports Cloud Functions deployment.

## What stays local

The emulator workflow can run Authentication, Firestore, Cloud Functions, and Storage on the developer machine. It does not deploy Cloud Functions or intentionally mutate live Firebase data. The Flutter app only connects to the emulators when both conditions are true:

1. the Flutter build is a debug build; and
2. `USE_FIREBASE_EMULATORS=true` is supplied as a Dart define.

The default remains production/staging Firebase configuration, so emulator routing cannot silently turn on in a release build. When emulator mode is active, the app displays a `LOCAL FIREBASE` debug banner.

## Why the local iOS runner uses the real project ID

The native iOS Firebase configuration identifies project `poly-circle-j5v6dy`. Firebase emulator services that interact with each other must use the same project ID as the app, otherwise Auth/Firestore/Functions can appear to be running while the app and seed data are actually in different emulator namespaces.

For that reason, the one-command iOS runner starts Auth, Firestore, Functions, and Storage emulators with `poly-circle-j5v6dy`, matching the native app configuration. This does **not** make the run a deployment. However, using a real project ID with emulators requires extra discipline because any Firebase product that is not explicitly emulated could otherwise reach a live resource.

Polycircle adds defense in depth:

- the runner starts every Firebase backend service currently used by the test path: Auth, Firestore, Functions, and Storage;
- Flutter routes Auth, Firestore, and Functions explicitly to localhost only in debug emulator mode;
- the local seed requires Auth + Firestore emulator host variables;
- those seed hosts must be loopback addresses;
- seeding the real project ID additionally requires `POLYCIRCLE_ALLOW_REAL_PROJECT_EMULATOR=true`;
- the runner contains no deploy command;
- CI rules tests continue to use isolated `demo-*` project IDs.

Do not copy the real-project opt-in flag into unrelated scripts.

## Recommended path before every simulator run

From the repository root, first activate the pinned Functions runtime:

```bash
nvm use
```

Then run the development preflight:

```bash
bash tool/dev_preflight.sh
```

The preflight checks the required tools/runtime versions, verifies the native iOS and Android Firebase identifiers/configuration when those host directories are present, runs Flutter source analysis and tests, builds/tests the Functions package, and runs the client/backend contract suite. For the slower emulator-backed Firestore/Storage security suite, use:

```bash
bash tool/dev_preflight.sh --full
```

## One-command iOS local test run

After `nvm use`, the preferred simulator workflow is:

```bash
bash tool/run_ios_local.sh
```

That command:

1. refreshes the approved launcher branding if the exact logo file is locally available;
2. runs the development preflight;
3. checks for stale Firebase emulator processes on the configured ports;
4. starts Authentication, Firestore, Functions, and Storage emulators using the same project ID as the native iOS app;
5. seeds safe local fixture data through loopback-only Admin SDK emulator connections;
6. launches the iPhone 17 simulator build with explicit emulator routing; and
7. shuts the emulators down when the Flutter run exits.

To target another already-available Flutter device, pass its exact device name:

```bash
bash tool/run_ios_local.sh "iPhone 17 Pro"
```

The local fixture login is:

```text
Email: cam@local.polycircle.test
Password: LocalOnly123!
```

The fixture includes two Discover profiles with fictional nearby coordinates, an existing connection, seeded chat messages, and a relationship card so Discover, Connections, Messages, and Circle can be exercised without a paid deployment. The runner sets only the simulator's location to the same fictional North Atlantic origin; it never reads the Mac's location.

### Local Orbit density fixtures

Orbit Discovery can be previewed with exactly 2, 5, 10, 15, or 45 local candidates. Set the emulator-only fixture count before invoking the approved runner:

```bash
POLYCIRCLE_DISCOVER_FIXTURE_COUNT=5 bash tool/run_ios_local.sh "iPhone 17 Pro"
```

Replace `5` with `2`, `10`, `15`, or `45` for the other supported densities. The default remains `2`. The runner and seed both reject any other value, and the seed requires loopback Auth, Firestore, and Storage hosts plus the explicit real-project emulator acknowledgement. Reseeding clears prior local Cam-to-fixture Pass, Like, match, block, and conversation state so the requested visual population is reachable; it does not touch Jordan's existing local connection or any live Firebase data.

For a high-density visual review, keep the production default unchanged while
seeding Cam's local saved preference explicitly:

```bash
POLYCIRCLE_DISCOVER_FIXTURE_COUNT=15 POLYCIRCLE_DISCOVER_FIXTURE_RADIUS=50 bash tool/run_ios_local.sh "iPhone 17 Pro"
```

To exercise continuous 15-person paging through three complete batches, use:

```bash
POLYCIRCLE_DISCOVER_FIXTURE_COUNT=45 POLYCIRCLE_DISCOVER_FIXTURE_RADIUS=100 bash tool/run_ios_local.sh "iPhone 17 Pro"
```

The first-release backend creates a short-lived, backend-only Discover session
from a bounded pool of at most 120 eligible profiles. Its opaque cursor contains
no member UID or coordinate. A future production-scale geospatial index can
replace this bounded scan without changing the client paging contract or
exposing precise location.

The optional local radius accepts only the same reviewed values as the app and defaults to 20 miles when omitted.

Each Discover candidate also receives a fictional local-only portrait in the Storage emulator with a matching server-owned `profile_media` record. The app retrieves these through the normal protected profile-media callable, so the founder can review photographic Orbit nodes without adding public image URLs or production demo members. Source fixtures are documented under `functions/fixtures/discover_portraits/` and are never referenced by production client code.

The selected candidates use deterministic fictional distances distributed from approximately 1 to 95 miles. With a 15- or 45-person fixture, changing Cam's radius visibly moves candidates into or out of the Orbit: 5 miles shows the nearest group, 10 and 20 add progressively more, 50 shows most, and 100 shows all eligible fixtures. Exact coordinates remain in the emulator-only `member_locations` collection and are never production/demo profile fields.

## Manual emulator workflow

The steps below remain useful when the emulators need to stay running across multiple app launches. Prefer the one-command runner unless you specifically need this mode.

### Node version

Cloud Functions target Node 22. If `nvm` is installed, run this from the repository root before installing Function dependencies:

```bash
nvm use
```

The repository `.nvmrc` pins Node 22. Do not develop the Functions package under Node 26 just because Homebrew installed it globally; npm will warn that it is outside the supported engine.

### Start matching-project emulators

From the repository root:

```bash
cd functions
npm install
npm run build
cd ..
firebase emulators:start --project poly-circle-j5v6dy --only auth,firestore,functions,storage
```

Leave that terminal running. The Emulator Suite UI is configured on port `4000`.

### Seed safe local test data

With the emulators already running, open another terminal and run:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
POLYCIRCLE_ALLOW_REAL_PROJECT_EMULATOR=true \
GCLOUD_PROJECT=poly-circle-j5v6dy \
npm --prefix functions run seed:emulator
```

Do not remove any of those guard variables. The seed script refuses non-loopback hosts and refuses the real Polycircle project ID without the explicit emulator-only opt-in.

### Run the iOS Simulator against local Firebase

Open another terminal from the repository root:

```bash
flutter run -d "iPhone 17" --dart-define=USE_FIREBASE_EMULATORS=true
```

The default emulator host is `127.0.0.1`, which is appropriate for the iOS Simulator on the same Mac.

If a different loopback host is needed, override it explicitly:

```bash
flutter run \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

## Android Emulator

The native Android host is configured for Polycircle with application ID `com.polycircle.app`, the Google Services Gradle plugin, Java/Kotlin 17 compatibility, and cleartext disabled for production builds. The local development preflight now treats a missing or mismatched `android/app/google-services.json` as a hard failure and verifies both the Firebase project ID (`poly-circle-j5v6dy`) and Android package registration before a test cycle proceeds.

The Android Emulator normally reaches the host Mac at `10.0.2.2`. With a matching local `android/app/google-services.json` present, the expected debug emulator-routing command is:

```bash
flutter run \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

Do not use the real-project seed against `10.0.2.2`; the seed script intentionally requires local loopback because it runs on the Mac itself.

Automated Android debug APK builds are part of CI, but a successful CI build does not replace manual emulator/device validation. Real-device Android behavior, production signing, App Check enforcement against deployed staging services, and release networking must still pass their release gates before external beta.

## App Check

Debug builds continue to use Firebase App Check debug providers. Do not disable App Check enforcement in source code simply to make local development easier. Keep any debug tokens private and never commit them.

## Launcher branding

The approved master artwork is pinned in `docs/branding.md` by exact source filename and SHA-256 so the dark Polycircle logo cannot be confused with the lighter alternative.

The Flutter/native launcher icon is separate from artwork shown inside the app. Replacing or generating a Polycircle logo does not automatically replace iOS `AppIcon.appiconset` or Android launcher resources.

On the development Mac, place the exact approved PNG in the project root, `branding/`, Downloads, or Desktop under its original filename, or pass its full path explicitly, then run:

```bash
bash tool/install_branding.sh
```

or:

```bash
bash tool/install_branding.sh "/full/path/to/a_logo_for_an_app_named_polycircle_is_displayed.png"
```

The installer verifies the approved SHA-256 before writing anything. It generates the iOS AppIcon sizes when the native iOS asset catalog is present and Android legacy + round launcher mipmaps when Android native resources are present. It records the approved source hash beside generated native assets so preflight checks can identify stale branding. If Android adaptive-icon XML is detected, the script warns instead of pretending that adaptive branding has been visually validated.

The one-command iOS runner invokes the branding installer in optional mode automatically. If the approved PNG is in one of the known locations, the icons are refreshed before the build. If it is not present, functional testing can continue but the runner prints a branding warning.

After changing launcher icons, rebuild/reinstall the app. Simulator/device launchers can cache an old icon from a previously installed build.

## Security expectations

Local emulators are for development and automated testing only. Passing emulator tests does not replace staging validation of App Check, IAM, Cloud Functions deployment, indexes, Storage behavior, media processing, account deletion, moderation, or real-device behavior.

Protected-media workflows that depend on real Cloud Storage signing/processing should still be treated as staging release gates even if their Firestore/Functions logic is exercised locally.

## Before external beta

A real staging Firebase project must still have the required APIs/billing available for Cloud Functions deployment, and the release gates in `docs/release-gates.md` must pass before external beta distribution.
