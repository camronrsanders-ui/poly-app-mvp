#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Keep regenerated Android hosts on the permanent Polycircle application ID.
# Firebase registration and local google-services.json must use this same ID.
ANDROID_ORG="com.polycircle"
ANDROID_APP_ID="com.polycircle.app"

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
import re

app_id = 'com.polycircle.app'

manifest = Path('android/app/src/main/AndroidManifest.xml')
text = manifest.read_text(encoding='utf-8')
text = text.replace('android:label="polycircle"', 'android:label="Polycircle"')
manifest.write_text(text, encoding='utf-8')

# `flutter create --org com.polycircle --project-name polycircle` naturally
# produces com.polycircle.polycircle. Normalize both Gradle and MainActivity to
# the permanent application ID so disaster-recovery regeneration cannot drift
# away from the Firebase/store identity used by the committed native host.
gradle_files = [
    Path('android/app/build.gradle.kts'),
    Path('android/app/build.gradle'),
]
for gradle in gradle_files:
    if not gradle.exists():
        continue
    source = gradle.read_text(encoding='utf-8')
    source = re.sub(r'(namespace\s*=\s*["\'])[^"\']+(["\'])', rf'\1{app_id}\2', source)
    source = re.sub(r'(applicationId\s*=\s*["\'])[^"\']+(["\'])', rf'\1{app_id}\2', source)
    source = re.sub(r'(applicationId\s+["]) [^"]+(["])', rf'\1{app_id}\2', source)
    gradle.write_text(source, encoding='utf-8')

target_activity = Path('android/app/src/main/kotlin/com/polycircle/app/MainActivity.kt')
activities = list(Path('android/app/src/main').glob('**/MainActivity.kt'))
if activities:
    source_activity = activities[0]
    activity_text = source_activity.read_text(encoding='utf-8')
    activity_text = re.sub(r'^package\s+[^\s]+', f'package {app_id}', activity_text, count=1, flags=re.MULTILINE)
    target_activity.parent.mkdir(parents=True, exist_ok=True)
    target_activity.write_text(activity_text, encoding='utf-8')
    if source_activity != target_activity:
        source_activity.unlink()

# Emulator-only HTTP is required for Firebase Auth/Firestore/Functions/Storage
# on 10.0.2.2. Keep cleartext permission isolated to debug builds so release
# builds do not silently permit arbitrary HTTP traffic.
debug_manifest = Path('android/app/src/debug/AndroidManifest.xml')
debug_manifest.parent.mkdir(parents=True, exist_ok=True)
debug_manifest.write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="android.permission.INTERNET" />\n    <application android:usesCleartextTraffic="true" />\n</manifest>\n''', encoding='utf-8')
PY

printf '✓ Android package normalized to %s.\n' "$ANDROID_APP_ID"
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
printf '\nBefore the first Firebase-backed Android launch, android/app/google-services.json for com.polycircle.app must exist locally (it is git-ignored).\n'
