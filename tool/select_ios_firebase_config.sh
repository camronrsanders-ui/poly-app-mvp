#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '✗ %s\n' "$1" >&2
  exit 1
}

CONFIGURATION="${CONFIGURATION:-}"
SRCROOT="${SRCROOT:-}"
TARGET_BUILD_DIR="${TARGET_BUILD_DIR:-}"
UNLOCALIZED_RESOURCES_FOLDER_PATH="${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}"
PRODUCT_BUNDLE_IDENTIFIER="${PRODUCT_BUNDLE_IDENTIFIER:-}"

case "$CONFIGURATION" in
  *-production)
    ENVIRONMENT="production"
    EXPECTED_PROJECT_ID="poly-circle-j5v6dy"
    EXPECTED_BUNDLE_ID="com.polycircle.app"
    ;;
  *-staging)
    ENVIRONMENT="staging"
    EXPECTED_PROJECT_ID="polycircle-staging-82204f"
    EXPECTED_BUNDLE_ID="com.polycircle.app.staging"
    ;;
  *)
    fail "Unsupported iOS environment configuration: '$CONFIGURATION'. Use an explicit production or staging scheme."
    ;;
esac

[[ -n "$SRCROOT" ]] || fail "SRCROOT is missing."
[[ -n "$TARGET_BUILD_DIR" ]] || fail "TARGET_BUILD_DIR is missing."
[[ -n "$UNLOCALIZED_RESOURCES_FOLDER_PATH" ]] || fail "UNLOCALIZED_RESOURCES_FOLDER_PATH is missing."
[[ -n "$PRODUCT_BUNDLE_IDENTIFIER" ]] || fail "PRODUCT_BUNDLE_IDENTIFIER is missing."

SOURCE_PLIST="$SRCROOT/Runner/Firebase/$ENVIRONMENT/GoogleService-Info.plist"

[[ -f "$SOURCE_PLIST" ]] || fail "Missing Firebase plist for iOS $ENVIRONMENT: $SOURCE_PLIST"

ACTUAL_BUNDLE_ID="$(
  /usr/libexec/PlistBuddy \
    -c 'Print :BUNDLE_ID' \
    "$SOURCE_PLIST" \
    2>/dev/null || true
)"

ACTUAL_PROJECT_ID="$(
  /usr/libexec/PlistBuddy \
    -c 'Print :PROJECT_ID' \
    "$SOURCE_PLIST" \
    2>/dev/null || true
)"

[[ "$PRODUCT_BUNDLE_IDENTIFIER" == "$EXPECTED_BUNDLE_ID" ]] || {
  fail "iOS build bundle '$PRODUCT_BUNDLE_IDENTIFIER' does not match expected $ENVIRONMENT bundle '$EXPECTED_BUNDLE_ID'."
}

[[ "$ACTUAL_BUNDLE_ID" == "$EXPECTED_BUNDLE_ID" ]] || {
  fail "Firebase plist BUNDLE_ID '$ACTUAL_BUNDLE_ID' does not match expected '$EXPECTED_BUNDLE_ID'."
}

[[ "$ACTUAL_PROJECT_ID" == "$EXPECTED_PROJECT_ID" ]] || {
  fail "Firebase plist PROJECT_ID '$ACTUAL_PROJECT_ID' does not match expected '$EXPECTED_PROJECT_ID'."
}

DESTINATION_DIR="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
DESTINATION="$DESTINATION_DIR/GoogleService-Info.plist"

mkdir -p "$DESTINATION_DIR"
cp "$SOURCE_PLIST" "$DESTINATION"

printf '✓ selected Firebase config for iOS %s (%s -> %s)\n' \
  "$ENVIRONMENT" \
  "$EXPECTED_BUNDLE_ID" \
  "$EXPECTED_PROJECT_ID"
