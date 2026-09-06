#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Keep runtime selection inside this script so opening a new terminal does not
# accidentally run Functions/Firebase tooling with incompatible globals.
# shellcheck disable=SC1091
source "$ROOT_DIR/tool/ensure_node22.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/tool/ensure_java21.sh"

ENVIRONMENT="${1:-}"
FULL=0

if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "staging" ]]; then
  printf "Usage: bash tool/dev_preflight.sh <production|staging> [--full]\n" >&2
  exit 1
fi

if [[ "${2:-}" == "--full" ]]; then
  FULL=1
elif [[ -n "${2:-}" ]]; then
  printf "Unknown dev_preflight option: %s\n" "${2:-}" >&2
  exit 1
fi

case "$ENVIRONMENT" in
  production)
    EXPECTED_FIREBASE_PROJECT_ID="poly-circle-j5v6dy"
    EXPECTED_IOS_BUNDLE_ID="com.polycircle.app"
    EXPECTED_ANDROID_APP_ID="com.polycircle.app"
    IOS_FIREBASE_PLIST="ios/Runner/Firebase/production/GoogleService-Info.plist"
    ANDROID_FIREBASE_JSON="android/app/src/production/google-services.json"
    ;;
  staging)
    EXPECTED_FIREBASE_PROJECT_ID="polycircle-staging-82204f"
    EXPECTED_IOS_BUNDLE_ID="com.polycircle.app.staging"
    EXPECTED_ANDROID_APP_ID="com.polycircle.app.staging"
    IOS_FIREBASE_PLIST="ios/Runner/Firebase/staging/GoogleService-Info.plist"
    ANDROID_FIREBASE_JSON="android/app/src/staging/google-services.json"
    ;;
esac

export ANDROID_FIREBASE_JSON

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

JAVA_VERSION_OUTPUT="$(java -version 2>&1)" || fail "Java 21 or newer must be executable after runtime activation."
JAVA_VERSION_RAW="${JAVA_VERSION_OUTPUT%%$'\n'*}"
JAVA_MAJOR="$(printf '%s' "$JAVA_VERSION_RAW" | sed -E 's/.*version "([0-9]+).*/\1/' || true)"
if [[ ! "$JAVA_MAJOR" =~ ^[0-9]+$ ]]; then
  fail "Could not determine a supported Java major version from: $JAVA_VERSION_RAW. Polycircle local Firebase emulators require Java 21 or newer."
elif (( JAVA_MAJOR < 21 )); then
  fail "Java 21 or newer is required for our emulator test setup. Current major is $JAVA_MAJOR."
else
  ok "Java $JAVA_MAJOR is compatible"
fi

if [[ -d ios ]]; then
  [[ -f "$IOS_FIREBASE_PLIST" ]] \
    || fail "$IOS_FIREBASE_PLIST is missing. The iOS app will not initialize Firebase correctly."
  ok "Firebase iOS config present for $ENVIRONMENT"

  if command -v plutil >/dev/null 2>&1; then
    BUNDLE_ID="$(plutil -extract BUNDLE_ID raw -o - "$IOS_FIREBASE_PLIST" 2>/dev/null || true)"
    PROJECT_ID="$(plutil -extract PROJECT_ID raw -o - "$IOS_FIREBASE_PLIST" 2>/dev/null || true)"
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

if [[ -d android ]]; then
  [[ -f "$ANDROID_FIREBASE_JSON" ]] \
    || fail "$ANDROID_FIREBASE_JSON is missing. The Android app will not initialize Firebase correctly."

  ANDROID_GRADLE_FILE=""
  if [[ -f android/app/build.gradle.kts ]]; then
    ANDROID_GRADLE_FILE="android/app/build.gradle.kts"
  elif [[ -f android/app/build.gradle ]]; then
    ANDROID_GRADLE_FILE="android/app/build.gradle"
  else
    fail "Android app Gradle configuration is missing (expected android/app/build.gradle.kts or android/app/build.gradle)."
  fi

  ANDROID_PROJECT_ID="$(node -e 'const fs=require("fs"); try { const j=JSON.parse(fs.readFileSync(process.env.ANDROID_FIREBASE_JSON,"utf8")); process.stdout.write(j.project_info?.project_id || ""); } catch (_) { process.exit(2); }' 2>/dev/null || true)"
  ANDROID_PACKAGE_NAMES="$(node -e 'const fs=require("fs"); try { const j=JSON.parse(fs.readFileSync(process.env.ANDROID_FIREBASE_JSON,"utf8")); const names=(j.client || []).map((client) => client.client_info?.android_client_info?.package_name).filter(Boolean); process.stdout.write(names.join(",")); } catch (_) { process.exit(2); }' 2>/dev/null || true)"
  ANDROID_MATCHING_APP_ID="$(EXPECTED_ANDROID_APP_ID="$EXPECTED_ANDROID_APP_ID" node -e 'const fs=require("fs"); try { const j=JSON.parse(fs.readFileSync(process.env.ANDROID_FIREBASE_JSON,"utf8")); const expected=process.env.EXPECTED_ANDROID_APP_ID || ""; const match=(j.client || []).find((client) => client.client_info?.android_client_info?.package_name === expected); process.stdout.write(match?.client_info?.mobilesdk_app_id || ""); } catch (_) { process.exit(2); }' 2>/dev/null || true)"
  if [[ -z "$ANDROID_PROJECT_ID" ]]; then
    fail "Could not read project_info.project_id from $ANDROID_FIREBASE_JSON."
  elif [[ "$ANDROID_PROJECT_ID" != "$EXPECTED_FIREBASE_PROJECT_ID" ]]; then
    fail "Android Firebase project ID is '$ANDROID_PROJECT_ID'; expected '$EXPECTED_FIREBASE_PROJECT_ID'. Emulator and app project IDs would not match."
  fi
  ok "Firebase Android project ID matches local runner"

  if [[ -z "$ANDROID_PACKAGE_NAMES" ]]; then
    fail "Could not read Android package names from $ANDROID_FIREBASE_JSON."
  elif [[ -z "$ANDROID_MATCHING_APP_ID" ]]; then
    fail "Firebase Android config does not contain package '$EXPECTED_ANDROID_APP_ID'. Found: $ANDROID_PACKAGE_NAMES"
  fi
  ok "Firebase Android package matches Polycircle"
  ok "Firebase Android app registration resolved for $EXPECTED_ANDROID_APP_ID"

  if ! grep -Fq 'com.google.gms.google-services' "$ANDROID_GRADLE_FILE"; then
    fail "Google Services Gradle plugin is not applied in $ANDROID_GRADLE_FILE. Firebase Android configuration would not be packaged."
  fi
  ok "Android Google Services Gradle plugin configured"
else
  warn "No android/ directory in this checkout; Android APK/device validation remains blocked until the native Flutter host is generated and configured."
fi

printf '\nRunning source checks...\n'
flutter pub get
# Match the CI analyzer scope so a local preflight cannot pass while CI would
# fail on tests, generated-adjacent Dart files, or other analyzed project code.
flutter analyze
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
  printf "For the full emulator-backed security suite, run: bash tool/dev_preflight.sh "$ENVIRONMENT" --full\n"
fi
