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

  flutter create --platforms=ios .

  if [[ -n "$backup_plist" && -f "$backup_plist" ]]; then
    mkdir -p "$(dirname "$PLIST")"
    cp "$backup_plist" "$PLIST"
    ok "preserved GoogleService-Info.plist while repairing iOS project"
  fi
fi

[[ -f "$PROJECT_FILE" ]] || fail "iOS Xcode project is still incomplete after repair: $PROJECT_FILE missing."
[[ -f "$INFO_PLIST" ]] || fail "iOS Runner Info.plist is still missing after repair."

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
