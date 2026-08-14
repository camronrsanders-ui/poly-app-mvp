#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ok() { printf '✓ %s\n' "$1"; }
warn() { printf '⚠ %s\n' "$1" >&2; }
fail() { printf '✗ %s\n' "$1" >&2; exit 1; }

command -v flutter >/dev/null 2>&1 || fail "flutter is required but was not found in PATH."

PLIST="ios/Runner/GoogleService-Info.plist"
PROJECT_FILE="ios/Runner.xcodeproj/project.pbxproj"
INFO_PLIST="ios/Runner/Info.plist"
EXPECTED_IOS_BUNDLE_ID="com.polycircle.app"

backup_plist=""
cleanup() {
  if [[ -n "$backup_plist" && -f "$backup_plist" ]]; then
    rm -f "$backup_plist"
  fi
}
trap cleanup EXIT

if [[ ! -f "$PROJECT_FILE" || ! -f "$INFO_PLIST" ]]; then
  printf 'Repairing incomplete Flutter iOS project shell...\n'

  if [[ -f "$PLIST" ]]; then
    backup_plist="$(mktemp -t polycircle-google-service-info.XXXXXX)"
    cp "$PLIST" "$backup_plist"
  fi

  # Generate a Polycircle-native bundle namespace at creation time so a repaired
  # host does not briefly inherit Flutter's com.example template identity.
  flutter create --platforms=ios --org com.polycircle .

  if [[ -n "$backup_plist" && -f "$backup_plist" ]]; then
    mkdir -p "$(dirname "$PLIST")"
    cp "$backup_plist" "$PLIST"
    ok "preserved GoogleService-Info.plist while repairing iOS project"
  fi
fi

[[ -f "$PROJECT_FILE" ]] || fail "iOS Xcode project is still incomplete after repair: $PROJECT_FILE missing."
[[ -f "$INFO_PLIST" ]] || fail "iOS Runner Info.plist is still missing after repair."

# Older/generated project shells may still carry the Flutter template bundle
# identifier. Normalize those safely to the Firebase-tested Polycircle ID.
python3 - <<'PY'
from pathlib import Path

project = Path('ios/Runner.xcodeproj/project.pbxproj')
text = project.read_text(encoding='utf-8')
updated = text
for legacy in ('com.example.polycircle', 'com.mycompany.polycircle'):
    updated = updated.replace(
        f'{legacy}.RunnerTests',
        'com.polycircle.app.RunnerTests',
    )
    updated = updated.replace(legacy, 'com.polycircle.app')
if updated != text:
    project.write_text(updated, encoding='utf-8')
PY

if grep -Eq 'PRODUCT_BUNDLE_IDENTIFIER = (com\.example\.polycircle|com\.mycompany\.polycircle)' "$PROJECT_FILE"; then
  fail "A legacy iOS bundle identifier remains in $PROJECT_FILE."
fi
if ! grep -Fq "PRODUCT_BUNDLE_IDENTIFIER = $EXPECTED_IOS_BUNDLE_ID;" "$PROJECT_FILE"; then
  fail "Polycircle iOS bundle identifier '$EXPECTED_IOS_BUNDLE_ID' was not found in $PROJECT_FILE."
fi
if ! grep -Fq "PRODUCT_BUNDLE_IDENTIFIER = $EXPECTED_IOS_BUNDLE_ID.RunnerTests;" "$PROJECT_FILE"; then
  fail "Polycircle RunnerTests bundle identifier '$EXPECTED_IOS_BUNDLE_ID.RunnerTests' was not found in $PROJECT_FILE."
fi

ok "iOS bundle identifier matches the Polycircle Firebase app"

# Flutter project regeneration may reset the native deployment target to 13.0,
# while the Firebase Apple SDK packages used by Polycircle require iOS 15+.
# Normalize all known stale targets before Xcode gets a chance to fail.
if grep -Eq 'IPHONEOS_DEPLOYMENT_TARGET = (13|14)(\.[0-9]+)?;' "$PROJECT_FILE"; then
  sed -E -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = (13|14)(\.[0-9]+)?;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' "$PROJECT_FILE"
  ok "raised stale iOS deployment targets to 15.0"
fi

if [[ -f ios/Podfile ]] && grep -Eq "platform :ios, '(13|14)(\.[0-9]+)?'" ios/Podfile; then
  sed -E -i '' "s/platform :ios, '(13|14)(\.[0-9]+)?'/platform :ios, '15.0'/g" ios/Podfile
  ok "raised Podfile iOS platform to 15.0"
fi

if grep -Eq 'IPHONEOS_DEPLOYMENT_TARGET = (13|14)(\.[0-9]+)?;' "$PROJECT_FILE"; then
  fail "A stale iOS deployment target below 15.0 remains in $PROJECT_FILE."
fi

ok "iOS project shell is complete and deployment target is Firebase-compatible"

if [[ ! -f "$PLIST" ]]; then
  warn "GoogleService-Info.plist is missing. Restore your local Firebase iOS plist before launching Polycircle."
fi
