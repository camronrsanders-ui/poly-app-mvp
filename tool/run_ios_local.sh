#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Select the Functions runtime in this shell before any npm/Firebase work.
# shellcheck disable=SC1091
source "$ROOT_DIR/tool/ensure_node22.sh"

DEVICE="${1:-iPhone 17}"
FIREBASE_PROJECT_ID="poly-circle-j5v6dy"

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH="$(git branch --show-current 2>/dev/null || true)"
  if [[ -n "$BRANCH" && "$BRANCH" != "restart-foundation" ]]; then
    printf "⚠ Current branch is '%s'; Polycircle active development is on 'restart-foundation'.\n" "$BRANCH" >&2
  fi
fi

# Repair the native iOS shell before any deeper validation. Flutter project
# regeneration may restore a stale 13.0 deployment target, so this also keeps
# the target at the Firebase-compatible iOS 15.0 floor automatically.
bash tool/ensure_ios_runtime.sh

# Refresh launcher icons automatically whenever the exact approved logo is
# available locally. Missing artwork is a branding warning, not a reason to
# block functional emulator testing.
bash tool/install_branding.sh --if-present

bash tool/dev_preflight.sh

printf '\nStarting Polycircle local Firebase test run\n'
printf 'Device: %s\n' "$DEVICE"
printf 'Firebase project ID: %s (ALL USED SERVICES ROUTED TO LOCAL EMULATORS)\n\n' "$FIREBASE_PROJECT_ID"

# Capture Flutter's device list once. Avoid piping `flutter devices` directly
# into grep while `pipefail` is enabled: grep -q may close the pipe as soon as
# it finds a match, causing Flutter to receive SIGPIPE and making a successful
# lookup appear to have failed.
DEVICES_OUTPUT="$(flutter devices)"
DEVICE_ID=""
while IFS= read -r line; do
  if [[ "$line" == *"$DEVICE (mobile)"* || "$line" == *"$DEVICE"* ]]; then
    # Flutter's human-readable format separates fields with the bullet glyph.
    # Resolve the stable device ID and use it for launch instead of relying on
    # a display-name match that can vary across Flutter/Xcode versions.
    rest="${line#*• }"
    candidate="${rest%% •*}"
    candidate="${candidate//[[:space:]]/}"
    if [[ -n "$candidate" ]]; then
      DEVICE_ID="$candidate"
      break
    fi
  fi
done <<< "$DEVICES_OUTPUT"

if [[ -z "$DEVICE_ID" ]]; then
  printf "Requested Flutter device '%s' was not found.\n\nAvailable devices:\n%s\n" "$DEVICE" "$DEVICES_OUTPUT" >&2
  exit 1
fi

printf 'Resolved Flutter device ID: %s\n' "$DEVICE_ID"

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

# The iOS native Firebase configuration already identifies this real project.
# Firebase requires the app and CLI emulator project IDs to match for
# cross-service emulator behavior. Every Polycircle service used by this run is
# explicitly routed to localhost, and the seed script adds a second loopback +
# opt-in guard before allowing this real project ID in an emulator process.
RUN_COMMAND="FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 POLYCIRCLE_ALLOW_REAL_PROJECT_EMULATOR=true GCLOUD_PROJECT=$FIREBASE_PROJECT_ID npm --prefix functions run seed:emulator && flutter run -d \"$DEVICE_ID\" --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1"

firebase emulators:exec \
  --project "$FIREBASE_PROJECT_ID" \
  --only auth,firestore,functions,storage \
  "$RUN_COMMAND"
