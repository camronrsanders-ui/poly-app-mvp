#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

EXPECTED_SHA="45ad99e923294cea8d33457c2f4200e82affa10efa5c011cdd691f0bdd392f20"
EXPECTED_NAME="a_logo_for_an_app_named_polycircle_is_displayed.png"
OPTIONAL=0
if [[ "${1:-}" == "--if-present" ]]; then
  OPTIONAL=1
  shift
fi
SOURCE="${1:-}"

fail() { printf '✗ %s\n' "$1" >&2; exit 1; }
ok() { printf '✓ %s\n' "$1"; }
warn() { printf '⚠ %s\n' "$1" >&2; }

if [[ -z "$SOURCE" ]]; then
  for candidate in \
    "$ROOT_DIR/$EXPECTED_NAME" \
    "$ROOT_DIR/branding/$EXPECTED_NAME" \
    "$HOME/Downloads/$EXPECTED_NAME" \
    "$HOME/Desktop/$EXPECTED_NAME"; do
    if [[ -f "$candidate" ]]; then
      SOURCE="$candidate"
      break
    fi
  done
fi

if [[ -z "$SOURCE" ]]; then
  if (( OPTIONAL == 1 )); then
    warn "Approved Polycircle logo is not present locally; launcher branding was not regenerated."
    warn "Place $EXPECTED_NAME in the repo root, branding/, Downloads, or Desktop and rerun."
    exit 0
  fi
  fail "Approved logo not found. Pass its path: bash tool/install_branding.sh /path/to/$EXPECTED_NAME"
fi
[[ -f "$SOURCE" ]] || fail "Logo file does not exist: $SOURCE"
command -v shasum >/dev/null 2>&1 || fail "shasum is required to verify the approved artwork."
command -v sips >/dev/null 2>&1 || fail "macOS 'sips' is required to generate launcher sizes."

ACTUAL_SHA="$(shasum -a 256 "$SOURCE" | awk '{print $1}')"
[[ "$ACTUAL_SHA" == "$EXPECTED_SHA" ]] \
  || fail "Logo hash does not match the approved Polycircle artwork. Refusing to install a substitute."
ok "Approved Polycircle master logo verified"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
cp "$SOURCE" "$WORK_DIR/master.png"

make_png() {
  local size="$1"
  local output="$2"
  mkdir -p "$(dirname "$output")"
  sips -z "$size" "$size" "$WORK_DIR/master.png" --out "$output" >/dev/null
}

IOS_SET="$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset"
if [[ -d "$ROOT_DIR/ios/Runner/Assets.xcassets" ]]; then
  mkdir -p "$IOS_SET"
  make_png 20 "$IOS_SET/Icon-App-20x20@1x.png"
  make_png 40 "$IOS_SET/Icon-App-20x20@2x.png"
  make_png 60 "$IOS_SET/Icon-App-20x20@3x.png"
  make_png 29 "$IOS_SET/Icon-App-29x29@1x.png"
  make_png 58 "$IOS_SET/Icon-App-29x29@2x.png"
  make_png 87 "$IOS_SET/Icon-App-29x29@3x.png"
  make_png 40 "$IOS_SET/Icon-App-40x40@1x.png"
  make_png 80 "$IOS_SET/Icon-App-40x40@2x.png"
  make_png 120 "$IOS_SET/Icon-App-40x40@3x.png"
  make_png 120 "$IOS_SET/Icon-App-60x60@2x.png"
  make_png 180 "$IOS_SET/Icon-App-60x60@3x.png"
  make_png 76 "$IOS_SET/Icon-App-76x76@1x.png"
  make_png 152 "$IOS_SET/Icon-App-76x76@2x.png"
  make_png 167 "$IOS_SET/Icon-App-83.5x83.5@2x.png"
  make_png 1024 "$IOS_SET/Icon-App-1024x1024@1x.png"

  cat > "$IOS_SET/Contents.json" <<'JSON'
{
  "images" : [
    {"idiom":"iphone","size":"20x20","scale":"2x","filename":"Icon-App-20x20@2x.png"},
    {"idiom":"iphone","size":"20x20","scale":"3x","filename":"Icon-App-20x20@3x.png"},
    {"idiom":"iphone","size":"29x29","scale":"1x","filename":"Icon-App-29x29@1x.png"},
    {"idiom":"iphone","size":"29x29","scale":"2x","filename":"Icon-App-29x29@2x.png"},
    {"idiom":"iphone","size":"29x29","scale":"3x","filename":"Icon-App-29x29@3x.png"},
    {"idiom":"iphone","size":"40x40","scale":"2x","filename":"Icon-App-40x40@2x.png"},
    {"idiom":"iphone","size":"40x40","scale":"3x","filename":"Icon-App-40x40@3x.png"},
    {"idiom":"iphone","size":"60x60","scale":"2x","filename":"Icon-App-60x60@2x.png"},
    {"idiom":"iphone","size":"60x60","scale":"3x","filename":"Icon-App-60x60@3x.png"},
    {"idiom":"ipad","size":"20x20","scale":"1x","filename":"Icon-App-20x20@1x.png"},
    {"idiom":"ipad","size":"20x20","scale":"2x","filename":"Icon-App-20x20@2x.png"},
    {"idiom":"ipad","size":"29x29","scale":"1x","filename":"Icon-App-29x29@1x.png"},
    {"idiom":"ipad","size":"29x29","scale":"2x","filename":"Icon-App-29x29@2x.png"},
    {"idiom":"ipad","size":"40x40","scale":"1x","filename":"Icon-App-40x40@1x.png"},
    {"idiom":"ipad","size":"40x40","scale":"2x","filename":"Icon-App-40x40@2x.png"},
    {"idiom":"ipad","size":"76x76","scale":"1x","filename":"Icon-App-76x76@1x.png"},
    {"idiom":"ipad","size":"76x76","scale":"2x","filename":"Icon-App-76x76@2x.png"},
    {"idiom":"ipad","size":"83.5x83.5","scale":"2x","filename":"Icon-App-83.5x83.5@2x.png"},
    {"idiom":"ios-marketing","size":"1024x1024","scale":"1x","filename":"Icon-App-1024x1024@1x.png"}
  ],
  "info" : {"author":"xcode","version":1}
}
JSON
  printf '%s\n' "$EXPECTED_SHA" > "$IOS_SET/.polycircle-source-sha256"
  ok "iOS AppIcon set generated from approved logo"
else
  warn "iOS native asset catalog is not present in this checkout; iOS icon generation skipped."
fi

if [[ -d "$ROOT_DIR/android/app/src/main/res" ]]; then
  declare -a ANDROID_ICONS=(
    "mipmap-mdpi:48"
    "mipmap-hdpi:72"
    "mipmap-xhdpi:96"
    "mipmap-xxhdpi:144"
    "mipmap-xxxhdpi:192"
  )
  for spec in "${ANDROID_ICONS[@]}"; do
    density="${spec%%:*}"
    size="${spec##*:}"
    make_png "$size" "$ROOT_DIR/android/app/src/main/res/$density/ic_launcher.png"
    make_png "$size" "$ROOT_DIR/android/app/src/main/res/$density/ic_launcher_round.png"
  done
  printf '%s\n' "$EXPECTED_SHA" > "$ROOT_DIR/android/app/src/main/res/.polycircle-source-sha256"
  ok "Android legacy/round launcher mipmaps generated from approved logo"

  if find "$ROOT_DIR/android/app/src/main/res" -path '*mipmap-anydpi-v26*' -name 'ic_launcher*.xml' -print -quit | grep -q .; then
    warn "Android adaptive-icon XML exists. Legacy/round mipmaps are updated, but adaptive foreground/background still require visual review before Android branding is marked complete."
  fi
else
  warn "Android native resources are not present in this checkout; Android icon generation skipped."
fi

printf '\nBranding installation finished. Rebuild/reinstall the app; launcher caches may keep an old icon until the prior app is removed.\n'
