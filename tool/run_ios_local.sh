#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Select the Functions/Firebase runtimes in this shell before any npm/Firebase work.
# shellcheck disable=SC1091
source "$ROOT_DIR/tool/ensure_node22.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/tool/ensure_java21.sh"

DEVICE="${1:-iPhone 17}"
FIREBASE_PROJECT_ID="poly-circle-j5v6dy"
DISCOVER_FIXTURE_COUNT="${POLYCIRCLE_DISCOVER_FIXTURE_COUNT:-2}"
DISCOVER_FIXTURE_RADIUS="${POLYCIRCLE_DISCOVER_FIXTURE_RADIUS:-20}"
EMULATOR_STATE_DIR="$ROOT_DIR/.local/firebase-emulator-data"
mkdir -p "$EMULATOR_STATE_DIR"

case "$DISCOVER_FIXTURE_COUNT" in
  2|5|10|15) ;;
  *)
    printf "POLYCIRCLE_DISCOVER_FIXTURE_COUNT must be 2, 5, 10, or 15 (received '%s').\n" "$DISCOVER_FIXTURE_COUNT" >&2
    exit 1
    ;;
esac

case "$DISCOVER_FIXTURE_RADIUS" in
  5|10|20|30|50|100) ;;
  *)
    printf "POLYCIRCLE_DISCOVER_FIXTURE_RADIUS must be 5, 10, 20, 30, 50, or 100 (received '%s').\n" "$DISCOVER_FIXTURE_RADIUS" >&2
    exit 1
    ;;
esac

EMULATOR_STATE_ARGS=("--export-on-exit=$EMULATOR_STATE_DIR")
if [[ -f "$EMULATOR_STATE_DIR/firebase-export-metadata.json" ]]; then
  EMULATOR_STATE_ARGS=("--import=$EMULATOR_STATE_DIR" "--export-on-exit=$EMULATOR_STATE_DIR")
fi

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH="$(git branch --show-current 2>/dev/null || true)"
  if [[ -n "$BRANCH" && "$BRANCH" != "restart-foundation" ]]; then
    printf "⚠ Current branch is '%s'; Polycircle active development is on 'restart-foundation'.\n" "$BRANCH" >&2
  fi
fi

bash tool/ensure_ios_runtime.sh
bash tool/install_branding.sh --if-present
bash tool/dev_preflight.sh

printf '\nStarting Polycircle local Firebase test run\n'
printf 'Requested device: %s\n' "$DEVICE"
printf 'Firebase project ID: %s (ALL USED SERVICES ROUTED TO LOCAL EMULATORS)\n\n' "$FIREBASE_PROJECT_ID"
printf 'Discover fixture count: %s (emulator only)\n\n' "$DISCOVER_FIXTURE_COUNT"
printf 'Discover fixture radius: %s miles (emulator only)\n\n' "$DISCOVER_FIXTURE_RADIUS"

DEVICE_ID=""
if command -v xcrun >/dev/null 2>&1; then
  DEVICE_ID="$(xcrun simctl list devices booted 2>/dev/null | awk -v device="$DEVICE" '
    index($0, device " (") {
      for (i = 1; i <= NF; i++) {
        value = $i
        gsub(/[()]/, "", value)
        if (value ~ /^[0-9A-Fa-f-]{36}$/) {
          print value
          exit
        }
      }
    }
  ')"
fi

if [[ -z "$DEVICE_ID" ]]; then
  DEVICES_OUTPUT="$(flutter devices 2>&1 || true)"
  while IFS= read -r line; do
    if [[ "$line" == *"$DEVICE (mobile)"* || "$line" == *"$DEVICE"* ]]; then
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
    printf "Requested Flutter device '%s' was not found.\n\nAvailable device output:\n%s\n" "$DEVICE" "$DEVICES_OUTPUT" >&2
    exit 1
  fi
fi

printf '✓ Resolved launch target: %s (%s)\n' "$DEVICE" "$DEVICE_ID"

# Match the guarded emulator fixture's fictional North Atlantic origin. This
# configures only the selected simulator; it does not read or use Mac location.
xcrun simctl location "$DEVICE_ID" set "12.3456,-45.6789"
printf '✓ Simulator Discover location: fictional emulator coordinate\n'

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

RUN_COMMAND="FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 POLYCIRCLE_ALLOW_REAL_PROJECT_EMULATOR=true POLYCIRCLE_DISCOVER_FIXTURE_COUNT=$DISCOVER_FIXTURE_COUNT POLYCIRCLE_DISCOVER_FIXTURE_RADIUS=$DISCOVER_FIXTURE_RADIUS GCLOUD_PROJECT=$FIREBASE_PROJECT_ID npm --prefix functions run seed:emulator && flutter run -d \"$DEVICE_ID\" --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1"

firebase emulators:exec \
  --project "$FIREBASE_PROJECT_ID" \
  --only auth,firestore,functions,storage \
  "${EMULATOR_STATE_ARGS[@]}" \
  "$RUN_COMMAND"
