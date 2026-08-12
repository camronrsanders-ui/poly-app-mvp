#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Select the Functions/Firebase runtimes in this shell before any npm/Firebase work.
# shellcheck disable=SC1091
source "$ROOT_DIR/tool/ensure_node22.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/tool/ensure_java21.sh"

DEVICE="${1:-Android Emulator}"
FIREBASE_PROJECT_ID="poly-circle-j5v6dy"
ANDROID_HOST="10.0.2.2"

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH="$(git branch --show-current 2>/dev/null || true)"
  if [[ -n "$BRANCH" && "$BRANCH" != "restart-foundation" ]]; then
    printf "⚠ Current branch is '%s'; Polycircle active development is on 'restart-foundation'.\n" "$BRANCH" >&2
  fi
fi

if [[ ! -d android ]]; then
  printf "Android native project is missing.\n" >&2
  printf "Generate/commit the Flutter Android host before using this runner.\n" >&2
  printf "See docs/android-development.md for the guarded preparation steps.\n" >&2
  exit 1
fi

if [[ ! -f android/app/google-services.json ]]; then
  printf "Android Firebase configuration is missing: android/app/google-services.json\n" >&2
  printf "Register/verify the Android app for the Polycircle Firebase project before testing.\n" >&2
  printf "Do not copy an unrelated Firebase config into this repository.\n" >&2
  exit 1
fi

bash tool/install_branding.sh --if-present
bash tool/dev_preflight.sh

printf '\nStarting Polycircle Android local Firebase test run\n'
printf 'Device: %s\n' "$DEVICE"
printf 'Firebase project ID: %s (ALL USED SERVICES ROUTED TO LOCAL EMULATORS)\n' "$FIREBASE_PROJECT_ID"
printf 'Android emulator host bridge: %s\n\n' "$ANDROID_HOST"

if ! flutter devices | grep -Fq "$DEVICE"; then
  printf "Requested Flutter device '%s' was not found.\n\nAvailable devices:\n" "$DEVICE" >&2
  flutter devices >&2
  exit 1
fi

if command -v lsof >/dev/null 2>&1; then
  for port in 4000 5001 8080 9099 9199; do
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      printf "Firebase emulator port %s is already in use.\n" "$port" >&2
      printf "Close the old emulator/process first. Current listener:\n" >&2
      lsof -nP -iTCP:"$port" -sTCP:LISTEN >&2 || true
      exit 1
    fi
  done
else
  printf "⚠ lsof is unavailable; emulator port pre-check skipped.\n" >&2
fi

RUN_COMMAND="FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 POLYCIRCLE_ALLOW_REAL_PROJECT_EMULATOR=true GCLOUD_PROJECT=$FIREBASE_PROJECT_ID npm --prefix functions run seed:emulator && flutter run -d \"$DEVICE\" --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=$ANDROID_HOST"

firebase emulators:exec \
  --project "$FIREBASE_PROJECT_ID" \
  --only auth,firestore,functions,storage \
  "$RUN_COMMAND"
