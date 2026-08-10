#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEVICE="${1:-iPhone 17}"

./tool/dev_preflight.sh

printf '\nStarting Polycircle local Firebase test run\n'
printf 'Device: %s\n' "$DEVICE"
printf 'Firebase project: demo-polycircle (emulators only)\n\n'

if ! flutter devices | grep -Fq "$DEVICE"; then
  printf "Requested Flutter device '%s' was not found.\n\nAvailable devices:\n" "$DEVICE" >&2
  flutter devices >&2
  exit 1
fi

RUN_COMMAND="FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=demo-polycircle npm --prefix functions run seed:emulator && flutter run -d \"$DEVICE\" --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1"

firebase emulators:exec \
  --project demo-polycircle \
  --only auth,firestore,functions,storage \
  "$RUN_COMMAND"
