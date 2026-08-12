#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Keep the runtime selection inside this script so opening a new terminal does
# not accidentally run Functions tooling with an incompatible global Node.
# shellcheck disable=SC1091
source "$ROOT_DIR/tool/ensure_node22.sh"

FULL=0
if [[ "${1:-}" == "--full" ]]; then
  FULL=1
fi

EXPECTED_FIREBASE_PROJECT_ID="poly-circle-j5v6dy"
EXPECTED_IOS_BUNDLE_ID="com.mycompany.polycircle"
EXPECTED_BRANDING_SHA="45ad99e923294cea8d33457c2f4200e82affa10efa5c011cdd691f0bdd392f20"

ok() { printf '✓ %s\n' "$1"; }
warn() { printf '⚠ %s\n' "$1" >&2; }
fail() { printf '✗ %s\n' "$1" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required but was not found in PATH."
  ok "$1 found"
}

printf '\nPolycircle development preflight\n'
printf '===============================\n'

require_cmd bash
require_cmd flutter
require_cmd firebase
require_cmd node
require_cmd npm
require_cmd java

for script in tool/*.sh; do
  bash -n "$script" || fail "Shell syntax check failed for $script"
done
ok "development shell scripts parse cleanly"

bash tool/security_static_scan.sh

NODE_MAJOR="$(node -p "process.versions.node.split('.')[0]")"
if [[ "$NODE_MAJOR" != "22" ]]; then
  fail "Node 22 is required for Polycircle Functions. Current Node major is $NODE_MAJOR."
fi
ok "Node 22 active"

# Avoid piping java -version through head while pipefail is enabled. Some Java
# runtimes emit multiple lines and can receive SIGPIPE after head exits, which
# previously caused an otherwise-successful preflight to terminate here.
JAVA_VERSION_OUTPUT="$(java -version 2>&1)"
JAVA_VERSION_RAW="${JAVA_VERSION_OUTPUT%%$'\n'*}"
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
    PROJECT_ID="$(plutil -extract PROJECT_ID raw -o - ios/Runner/GoogleService-Info.plist 2>/dev/null || true)"
    if [[ -n "$BUNDLE_ID" && "$BUNDLE_ID" != "$EXPECTED_IOS_BUNDLE_ID" ]]; then
      fail "Firebase plist bundle ID is '$BUNDLE_ID'; expected '$EXPECTED_IOS_BUNDLE_ID'."
    fi
    if [[ -n "$PROJECT_ID" && "$PROJECT_ID" != "$EXPECTED_FIREBASE_PROJECT_ID" ]]; then
      fail "Firebase plist project ID is '$PROJECT_ID'; expected '$EXPECTED_FIREBASE_PROJECT_ID'. Emulator and app project IDs would not match."
    fi
    [[ -n "$BUNDLE_ID" ]] && ok "Firebase iOS bundle ID matches Polycircle"
    [[ -n "$PROJECT_ID" ]] && ok "Firebase iOS project ID matches local runner"
  fi

  if [[ -f ios/Runner.xcodeproj/project.pbxproj ]]; then
    if grep -q 'IPHONEOS_DEPLOYMENT_TARGET = 13\.0;' ios/Runner.xcodeproj/project.pbxproj; then
      fail "iOS deployment target 13.0 is still present. Firebase packages require the project to remain at iOS 15.0+."
    fi
    ok "No stale iOS 13 deployment target detected"
  fi

  IOS_ICON_SET="ios/Runner/Assets.xcassets/AppIcon.appiconset"
  if [[ ! -d "$IOS_ICON_SET" || ! -f "$IOS_ICON_SET/Contents.json" || ! -f "$IOS_ICON_SET/Icon-App-1024x1024@1x.png" ]]; then
    warn "Complete iOS AppIcon assets are not present. Run bash tool/install_branding.sh with the approved logo before branded validation."
  elif [[ -f "$IOS_ICON_SET/.polycircle-source-sha256" ]]; then
    INSTALLED_BRANDING_SHA="$(tr -d '[:space:]' < "$IOS_ICON_SET/.polycircle-source-sha256")"
    if [[ "$INSTALLED_BRANDING_SHA" == "$EXPECTED_BRANDING_SHA" ]]; then
      ok "iOS launcher assets were generated from the approved Polycircle logo"
    else
      warn "iOS launcher branding marker does not match the approved logo hash; regenerate branding."
    fi
  else
    warn "iOS launcher assets exist but have no Polycircle source-hash marker; regenerate branding before visual signoff."
  fi
else
  warn "No ios/ directory in this checkout; native iOS configuration checks were skipped."
fi

printf '\nRunning source checks...\n'
flutter pub get
flutter analyze lib
flutter test
ok "Flutter source checks passed"

# The repository does not yet commit npm lockfiles, so npm ci would fail on a
# fresh checkout. Keep this aligned with CI until lockfiles are intentionally
# generated/reviewed and committed.
npm --prefix functions install
npm --prefix functions run build
npm --prefix functions test
node --test tests/contracts/*.test.mjs
ok "Functions build/tests and client-backend contracts passed"

if (( FULL == 1 )); then
  printf '\nRunning full Firebase rules suite...\n'
  npm --prefix tests/security install
  firebase emulators:exec \
    --project demo-polycircle \
    --only firestore,storage \
    "npm --prefix tests/security test"
  ok "Firestore and Storage adversarial rules tests passed"
fi

printf '\nPreflight passed.\n'
if (( FULL == 0 )); then
  printf "For the full emulator-backed security suite, run: bash tool/dev_preflight.sh --full\n"
fi
