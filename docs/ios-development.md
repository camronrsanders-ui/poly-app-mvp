# iOS Development

## Production and staging environments

Polycircle uses explicit build-time iOS environments.

Configurations:

```text
Debug-production
Profile-production
Release-production

Debug-staging
Profile-staging
Release-staging
```

Bundle identities:

```text
production: com.polycircle.app
staging:    com.polycircle.app.staging
```

The staging app is displayed as `Polycircle Staging`.

## Firebase configuration

Real Firebase client configuration remains untracked:

```text
ios/Runner/Firebase/production/GoogleService-Info.plist
ios/Runner/Firebase/staging/GoogleService-Info.plist
```

`tool/select_ios_firebase_config.sh` validates the selected configuration, bundle ID, and Firebase project ID before copying the matching plist into the build.

Mappings:

```text
production
  com.polycircle.app
  poly-circle-j5v6dy

staging
  com.polycircle.app.staging
  polycircle-staging-82204f
```

There is no runtime Firebase project selector and no root `ios/Runner/GoogleService-Info.plist` fallback.

## Build commands

```bash
flutter build ios --flavor production --simulator --debug
flutter build ios --flavor staging --simulator --debug
```

Development preflight requires explicit environment selection:

```bash
bash tool/dev_preflight.sh production
bash tool/dev_preflight.sh staging
```

The one-command local iOS runner intentionally uses the staging environment.

## Release gates

Simulator build readiness does not close physical-iPhone testing, App Attest/DeviceCheck, staging callable/media/account-deletion E2E, Crashlytics delivery, signing/provisioning, or App Store acceptance.

App Check, Firestore cache policy, Firebase security boundaries, and product feature gates are not weakened by environment separation.
