#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Android currently mirrors the iOS development identifier. We can migrate both
# platforms to a production identifier together before store release.
ANDROID_ORG="com.example"
ANDROID_APP_ID="com.example.polycircle"

# shellcheck disable=SC1091
source "$ROOT_DIR/tool/ensure_java21.sh"

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH="$(git branch --show-current 2>/dev/null || true)"
  if [[ -n "$BRANCH" && "$BRANCH" != "restart-foundation" ]]; then
    printf "⚠ Current branch is '%s'; Polycircle active development is on 'restart-foundation'.\n" "$BRANCH" >&2
  fi
fi

printf 'Preparing Polycircle Android native host\n'
printf 'Android application ID: %s\n\n' "$ANDROID_APP_ID"

if [[ ! -d "$ROOT_DIR/android" ]]; then
  flutter create \
    --platforms=android \
    --org "$ANDROID_ORG" \
    --project-name polycircle \
    "$ROOT_DIR"
  printf '✓ Flutter Android host generated.\n'
else
  printf '✓ Android host already exists; generation skipped.\n'
fi

MANIFEST="$ROOT_DIR/android/app/src/main/AndroidManifest.xml"
[[ -f "$MANIFEST" ]] || {
  printf '✗ AndroidManifest.xml was not generated where expected.\n' >&2
  exit 1
}

python3 - <<'PY'
from pathlib import Path

manifest = Path('android/app/src/main/AndroidManifest.xml')
text = manifest.read_text(encoding='utf-8')
text = text.replace('android:label="polycircle"', 'android:label="Polycircle"')
manifest.write_text(text, encoding='utf-8')

# Emulator-only HTTP is required for Firebase Auth/Firestore/Functions/Storage
# on 10.0.2.2. Keep cleartext permission isolated to debug builds so release
# builds do not silently permit arbitrary HTTP traffic.
debug_manifest = Path('android/app/src/debug/AndroidManifest.xml')
debug_manifest.parent.mkdir(parents=True, exist_ok=True)
debug_manifest.write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="android.permission.INTERNET" />\n    <application android:usesCleartextTraffic="true" />\n</manifest>\n''', encoding='utf-8')
PY

printf '✓ Android display name set to Polycircle.\n'
printf '✓ Debug-only cleartext transport enabled for local Firebase emulators.\n'

bash tool/install_branding.sh --if-present
flutter pub get

printf '\nAndroid host bootstrap complete.\n'
printf 'Next verification gates:\n'
printf '  flutter analyze\n'
printf '  flutter test\n'
printf '  flutter build apk --debug\n'
printf '  flutter build ios --simulator --debug   # required iOS regression check\n'
printf '\nBefore the first Firebase-backed Android launch, android/app/google-services.json must exist locally (it is git-ignored).\n'
