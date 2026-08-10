#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FULL=0
if [[ "${1:-}" == "--full" ]]; then
  FULL=1
fi

ok() { printf '✓ %s\n' "$1"; }
warn() { printf '⚠ %s\n' "$1" >&2; }
fail() { printf '✗ %s\n' "$1" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required but was not found in PATH."
  ok "$1 found"
}

printf '\nPolycircle development preflight\n'
printf '===============================\n'

require_cmd flutter
require_cmd firebase
require_cmd node
require_cmd npm
require_cmd java

NODE_MAJOR="$(node -p "process.versions.node.split('.')[0]")"
if [[ "$NODE_MAJOR" != "22" ]]; then
  fail "Node 22 is required for Polycircle Functions. Current Node major is $NODE_MAJOR. Run 'nvm use' from the repo root and retry."
fi
ok "Node 22 active"

JAVA_VERSION_RAW="$(java -version 2>&1 | head -n 1)"
JAVA_MAJOR="$(printf '%s' "$JAVA_VERSION_RAW" | sed -E 's/.*version "([0-9]+).*/\1/' || true)"
if [[ ! "$JAVA_MAJOR" =~ ^[0-9]+$ ]]; then
  warn "Could not determine Java major version from: $JAVA_VERSION_RAW"
elif (( JAVA_MAJOR < 21 )); then
  fail "Java 21 or newer is required for our emulator test setup. Current major is $JAVA_MAJOR."
else
  ok "Java $JAVA_MAJOR is compatible"
fi

if [[ -d ios ]]; then
  [[ -f ios/Runner/GoogleService-Info.plist ]] \
    || fail "ios/Runner/GoogleService-Info.plist is missing. The iOS app will not initialize Firebase correctly."
  ok "GoogleService-Info.plist present"

  if command -v plutil >/dev/null 2>&1; then
    BUNDLE_ID="$(plutil -extract BUNDLE_ID raw -o - ios/Runner/GoogleService-Info.plist 2>/dev/null || true)"
    if [[ -n "$BUNDLE_ID" && "$BUNDLE_ID" != "com.mycompany.polycircle" ]]; then
      fail "Firebase plist bundle ID is '$BUNDLE_ID'; expected 'com.mycompany.polycircle'."
    fi
    [[ -n "$BUNDLE_ID" ]] && ok "Firebase iOS bundle ID matches Polycircle"
  fi

  if [[ -f ios/Runner.xcodeproj/project.pbxproj ]]; then
    if grep -q 'IPHONEOS_DEPLOYMENT_TARGET = 13\.0;' ios/Runner.xcodeproj/project.pbxproj; then
      fail "iOS deployment target 13.0 is still present. Firebase packages require the project to remain at iOS 15.0+."
    fi
    ok "No stale iOS 13 deployment target detected"
  fi

  if [[ ! -d ios/Runner/Assets.xcassets/AppIcon.appiconset ]]; then
    warn "iOS AppIcon asset set is missing. The app can still be debugged, but launcher branding is not ready."
  fi
else
  warn "No ios/ directory in this checkout; native iOS configuration checks were skipped."
fi

printf '\nRunning source checks...\n'
flutter pub get
flutter analyze lib
flutter test
ok "Flutter source checks passed"

npm --prefix functions ci
npm --prefix functions run build
npm --prefix functions test
node --test tests/contracts/*.test.mjs
ok "Functions build/tests and client-backend contracts passed"

if (( FULL == 1 )); then
  printf '\nRunning full Firebase rules suite...\n'
  npm --prefix tests/security ci
  firebase emulators:exec \
    --project demo-polycircle \
    --only firestore,storage \
    "npm --prefix tests/security test"
  ok "Firestore and Storage adversarial rules tests passed"
fi

printf '\nPreflight passed.\n'
if (( FULL == 0 )); then
  printf "For the full emulator-backed security suite, run: ./tool/dev_preflight.sh --full\n"
fi
