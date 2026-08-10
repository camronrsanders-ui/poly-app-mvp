#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEVICE="${1:-iPhone 17}"

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH="$(git branch --show-current 2>/dev/null || true)"
  if [[ -n "$BRANCH" && "$BRANCH" != "restart-foundation" ]]; then
    printf "⚠ Current branch is '%s'; Polycircle active development is on 'restart-foundation'.\n" "$BRANCH" >&2
  fi
fi

# Refresh launcher icons automatically whenever the exact approved logo is
# available locally. Missing artwork is a branding warning, not a reason to
# block functional emulator testing.
bash tool/install_branding.sh --if-present

bash tool/dev_preflight.sh

printf '\nStarting Polycircle local Firebase test run\n'
printf 'Device: %s\n' "$DEVICE"
printf 'Firebase project: demo-polycircle (emulators only)\n\n'

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

RUN_COMMAND="FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=demo-polycircle npm --prefix functions run seed:emulator && flutter run -d \"$DEVICE\" --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1"

firebase emulators:exec \
  --project demo-polycircle \
  --only auth,firestore,functions,storage \
  "$RUN_COMMAND"
