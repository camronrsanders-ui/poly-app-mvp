#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ok() { printf '✓ %s\n' "$1"; }
fail() { printf '✗ %s\n' "$1" >&2; exit 1; }

command -v flutter >/dev/null 2>&1 || {
  fail "flutter is required but was not found in PATH."
}

PROJECT_FILE="ios/Runner.xcodeproj/project.pbxproj"
INFO_PLIST="ios/Runner/Info.plist"
PRODUCTION_SCHEME="ios/Runner.xcodeproj/xcshareddata/xcschemes/production.xcscheme"
STAGING_SCHEME="ios/Runner.xcodeproj/xcshareddata/xcschemes/staging.xcscheme"

if [[ ! -f "$PROJECT_FILE" || ! -f "$INFO_PLIST" ]]; then
  printf 'Repairing incomplete Flutter iOS project shell...\n'

  flutter create \
    --platforms=ios \
    --org com.polycircle \
    .

  printf 'The Flutter shell was regenerated; restoring tracked Polycircle flavor configuration is required.\n' >&2
fi

[[ -f "$PROJECT_FILE" ]] || {
  fail "iOS Xcode project is incomplete: $PROJECT_FILE missing."
}

[[ -f "$INFO_PLIST" ]] || {
  fail "iOS Runner Info.plist is missing."
}

python3 - <<'PY2'
from pathlib import Path

project = Path("ios/Runner.xcodeproj/project.pbxproj")
text = project.read_text()
updated = text

for legacy in (
    "com.example.polycircle",
    "com.mycompany.polycircle",
):
    updated = updated.replace(
        f"{legacy}.RunnerTests",
        "com.polycircle.app.RunnerTests",
    )
    updated = updated.replace(
        legacy,
        "com.polycircle.app",
    )

if updated != text:
    project.write_text(updated)
PY2

if grep -Eq \
  'PRODUCT_BUNDLE_IDENTIFIER = (com\.example\.polycircle|com\.mycompany\.polycircle)' \
  "$PROJECT_FILE"
then
  fail "A legacy iOS bundle identifier remains in $PROJECT_FILE."
fi

for configuration in \
  Debug-production \
  Profile-production \
  Release-production \
  Debug-staging \
  Profile-staging \
  Release-staging
do
  grep -Fq "name = $configuration;" "$PROJECT_FILE" || {
    fail "Missing iOS build configuration: $configuration"
  }
done

grep -Fq \
  "PRODUCT_BUNDLE_IDENTIFIER = com.polycircle.app;" \
  "$PROJECT_FILE" || {
    fail "Production iOS bundle identifier is missing."
  }

grep -Fq \
  "PRODUCT_BUNDLE_IDENTIFIER = com.polycircle.app.staging;" \
  "$PROJECT_FILE" || {
    fail "Staging iOS bundle identifier is missing."
  }

grep -Fq \
  "PRODUCT_BUNDLE_IDENTIFIER = com.polycircle.app.RunnerTests;" \
  "$PROJECT_FILE" || {
    fail "Production RunnerTests bundle identifier is missing."
  }

grep -Fq \
  "PRODUCT_BUNDLE_IDENTIFIER = com.polycircle.app.staging.RunnerTests;" \
  "$PROJECT_FILE" || {
    fail "Staging RunnerTests bundle identifier is missing."
  }

[[ -f "$PRODUCTION_SCHEME" ]] || {
  fail "Production iOS scheme is missing."
}

[[ -f "$STAGING_SCHEME" ]] || {
  fail "Staging iOS scheme is missing."
}

if grep -Eq \
  'IPHONEOS_DEPLOYMENT_TARGET = (13|14)(\.[0-9]+)?;' \
  "$PROJECT_FILE"
then
  sed -E -i '' \
    's/IPHONEOS_DEPLOYMENT_TARGET = (13|14)(\.[0-9]+)?;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' \
    "$PROJECT_FILE"

  ok "raised stale iOS deployment targets to 15.0"
fi

if [[ -f ios/Podfile ]] && \
   grep -Eq \
     "platform :ios, '(13|14)(\.[0-9]+)?'" \
     ios/Podfile
then
  sed -E -i '' \
    "s/platform :ios, '(13|14)(\.[0-9]+)?'/platform :ios, '15.0'/g" \
    ios/Podfile

  ok "raised Podfile iOS platform to 15.0"
fi

if grep -Eq \
  'IPHONEOS_DEPLOYMENT_TARGET = (13|14)(\.[0-9]+)?;' \
  "$PROJECT_FILE"
then
  fail "A stale iOS deployment target below 15.0 remains."
fi

ok "iOS production/staging host structure is complete"
