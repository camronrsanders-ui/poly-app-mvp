#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Select the Functions/Firebase runtimes in this shell before any npm/Firebase work.
# shellcheck disable=SC1091
source "$ROOT_DIR/tool/ensure_node22.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/tool/ensure_java21.sh"

DEVICE_REQUEST="${1:-}"
FIREBASE_PROJECT_ID="poly-circle-j5v6dy"
ANDROID_HOST="${POLYCIRCLE_ANDROID_FIREBASE_HOST:-10.0.2.2}"
DISCOVER_FIXTURE_COUNT="${POLYCIRCLE_DISCOVER_FIXTURE_COUNT:-2}"
DISCOVER_FIXTURE_RADIUS="${POLYCIRCLE_DISCOVER_FIXTURE_RADIUS:-20}"
EMULATOR_STATE_DIR="$ROOT_DIR/.local/firebase-emulator-data"
mkdir -p "$EMULATOR_STATE_DIR"

case "$DISCOVER_FIXTURE_COUNT" in
  2|5|10|15|45) ;;
  *)
    printf "POLYCIRCLE_DISCOVER_FIXTURE_COUNT must be 2, 5, 10, 15, or 45 (received '%s').\n" "$DISCOVER_FIXTURE_COUNT" >&2
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

if [[ ! -d android ]]; then
  printf "Android native project is missing.\n" >&2
  printf "Run: bash tool/bootstrap_android_host.sh\n" >&2
  exit 1
fi

if [[ ! -f android/app/google-services.json ]]; then
  printf "Android Firebase configuration is missing: android/app/google-services.json\n" >&2
  printf "Download the config for package com.polycircle.app from the Polycircle Firebase project and place it there locally.\n" >&2
  printf "The file is intentionally git-ignored; do not commit it.\n" >&2
  exit 1
fi

bash tool/install_branding.sh --if-present
bash tool/dev_preflight.sh

DEVICES_JSON="$(flutter devices --machine 2>/dev/null || true)"
DEVICE_ID="$(printf '%s' "$DEVICES_JSON" | DEVICE_REQUEST="$DEVICE_REQUEST" node -e '
let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => { input += chunk; });
process.stdin.on("end", () => {
  let devices = [];
  try { devices = JSON.parse(input || "[]"); } catch (_) { process.exit(2); }
  const request = (process.env.DEVICE_REQUEST || "").toLowerCase();
  const android = devices.filter((device) => String(device.targetPlatform || "").startsWith("android"));
  const selected = request
    ? android.find((device) => String(device.id || "").toLowerCase() === request || String(device.name || "").toLowerCase() === request)
    : (android.find((device) => device.emulator === true) || android[0]);
  if (selected?.id) process.stdout.write(selected.id);
});
' 2>/dev/null || true)"

if [[ -z "$DEVICE_ID" ]]; then
  if [[ -n "$DEVICE_REQUEST" ]]; then
    printf "Requested Android Flutter device '%s' was not found.\n\nAvailable devices:\n" "$DEVICE_REQUEST" >&2
  else
    printf "No Android Flutter device was found. Start an Android emulator first.\n\nAvailable devices:\n" >&2
  fi
  flutter devices >&2 || true
  exit 1
fi

if command -v adb >/dev/null 2>&1 && [[ "$ANDROID_HOST" == "10.0.2.2" ]]; then
  IS_EMULATOR="$(adb -s "$DEVICE_ID" shell getprop ro.kernel.qemu 2>/dev/null | tr -d '\r' || true)"
  if [[ -n "$IS_EMULATOR" && "$IS_EMULATOR" != "1" ]]; then
    printf "Device '%s' does not appear to be an Android Emulator.\n" "$DEVICE_ID" >&2
    printf "The default 10.0.2.2 Firebase bridge is emulator-only. Physical-device routing is a separate test path.\n" >&2
    exit 1
  fi
fi

printf '\nStarting Polycircle Android local Firebase test run\n'
printf 'Resolved Android device: %s\n' "$DEVICE_ID"
printf 'Firebase project ID: %s (ALL USED SERVICES ROUTED TO LOCAL EMULATORS)\n' "$FIREBASE_PROJECT_ID"
printf 'Android emulator host bridge: %s\n\n' "$ANDROID_HOST"
printf 'Discover fixture count: %s (emulator only)\n\n' "$DISCOVER_FIXTURE_COUNT"
printf 'Discover fixture radius: %s miles (emulator only)\n\n' "$DISCOVER_FIXTURE_RADIUS"

if command -v adb >/dev/null 2>&1; then
  # adb geo fix takes longitude before latitude. This fictional coordinate
  # matches the guarded fixture and never reads a developer's location.
  adb -s "$DEVICE_ID" emu geo fix -45.6789 12.3456 >/dev/null
  printf '✓ Android emulator Discover location: fictional emulator coordinate\n'
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

RUN_COMMAND="FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 POLYCIRCLE_ALLOW_REAL_PROJECT_EMULATOR=true POLYCIRCLE_DISCOVER_FIXTURE_COUNT=$DISCOVER_FIXTURE_COUNT POLYCIRCLE_DISCOVER_FIXTURE_RADIUS=$DISCOVER_FIXTURE_RADIUS GCLOUD_PROJECT=$FIREBASE_PROJECT_ID npm --prefix functions run seed:emulator && flutter run -d \"$DEVICE_ID\" --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=$ANDROID_HOST"

firebase emulators:exec \
  --project "$FIREBASE_PROJECT_ID" \
  --only auth,firestore,functions,storage \
  "${EMULATOR_STATE_ARGS[@]}" \
  "$RUN_COMMAND"
