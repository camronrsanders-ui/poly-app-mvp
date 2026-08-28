#!/usr/bin/env bash
set -euo pipefail

STAGING_PROJECT_ID="polycircle-staging-82204f"
PRODUCTION_PROJECT_ID="poly-circle-j5v6dy"

usage() {
  printf '%s\n' \
    "Usage:" \
    "  bash tool/deploy_staging.sh --approved-head <git-sha> [--check-only] <component>" \
    "" \
    "Allowed components:" \
    "  firestore:rules" \
    "  firestore:indexes" \
    "  storage" \
    "  functions"
}

APPROVED_HEAD=""
CHECK_ONLY=0
COMPONENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --approved-head)
      [[ $# -ge 2 ]] || {
        echo "STOP: --approved-head requires a SHA" >&2
        exit 2
      }
      APPROVED_HEAD="$2"
      shift 2
      ;;
    --check-only)
      CHECK_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "STOP: unsupported option: $1" >&2
      exit 2
      ;;
    *)
      [[ -z "$COMPONENT" ]] || {
        echo "STOP: exactly one deploy component is permitted" >&2
        exit 2
      }
      COMPONENT="$1"
      shift
      ;;
  esac
done

[[ -n "$APPROVED_HEAD" ]] || {
  echo "STOP: --approved-head is required" >&2
  exit 2
}

case "$COMPONENT" in
  firestore:rules|firestore:indexes|storage|functions)
    ;;
  "")
    echo "STOP: explicit deploy component is required" >&2
    exit 2
    ;;
  *)
    echo "STOP: unsupported deploy component: $COMPONENT" >&2
    exit 2
    ;;
esac

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CURRENT_HEAD="$(git rev-parse HEAD)"

[[ "$CURRENT_HEAD" == "$APPROVED_HEAD" ]] || {
  echo "STOP: current HEAD is not the explicitly approved deploy head" >&2
  echo "Approved: $APPROVED_HEAD" >&2
  echo "Current:  $CURRENT_HEAD" >&2
  exit 1
}

git diff --cached --quiet || {
  echo "STOP: staged changes exist" >&2
  git diff --cached --name-status >&2
  exit 1
}

DEPLOY_SENSITIVE_PATHS=(
  firebase.json
  firestore.rules
  firestore.indexes.json
  storage.rules
  functions/src
  functions/package.json
  functions/package-lock.json
  tool/deploy_staging.sh
  tests/contracts/staging_deployment_guard_contract.test.mjs
)

DEPLOY_STATUS="$(
  git status --porcelain=v1 -- "${DEPLOY_SENSITIVE_PATHS[@]}"
)"

[[ -z "$DEPLOY_STATUS" ]] || {
  echo "STOP: deployment-sensitive files have local changes" >&2
  printf '%s\n' "$DEPLOY_STATUS" >&2
  exit 1
}

git fetch origin restart-foundation >/dev/null

REMOTE_HEAD="$(git rev-parse origin/restart-foundation)"
[[ "$REMOTE_HEAD" == "$CURRENT_HEAD" ]] || {
  echo "STOP: origin/restart-foundation does not match approved HEAD" >&2
  echo "Remote:  $REMOTE_HEAD" >&2
  echo "Current: $CURRENT_HEAD" >&2
  exit 1
}

FIREBASE_BIN="$(command -v firebase || true)"
NODE_BIN="$(command -v node || true)"
NPM_BIN="$(command -v npm || true)"

[[ -x "$FIREBASE_BIN" ]] || {
  echo "STOP: Firebase CLI unavailable" >&2
  exit 1
}
[[ -x "$NODE_BIN" ]] || {
  echo "STOP: Node unavailable" >&2
  exit 1
}
[[ -x "$NPM_BIN" ]] || {
  echo "STOP: npm unavailable" >&2
  exit 1
}

[[ "$STAGING_PROJECT_ID" != "$PRODUCTION_PROJECT_ID" ]] || {
  echo "STOP: staging and production project IDs unexpectedly match" >&2
  exit 1
}
[[ "$STAGING_PROJECT_ID" == "polycircle-staging-82204f" ]] || {
  echo "STOP: staging project ID changed unexpectedly" >&2
  exit 1
}

echo "===== STAGING DEPLOYMENT PREFLIGHT ====="
echo "Project:   $STAGING_PROJECT_ID"
echo "Component: $COMPONENT"
echo "HEAD:      $CURRENT_HEAD"

(
  cd functions
  "$NPM_BIN" run build
)

if (
  cd functions
  "$NPM_BIN" run 2>/dev/null | grep -Eq '^[[:space:]]+test($|:)'
); then
  (
    cd functions
    "$NPM_BIN" test
  )
fi

"$NODE_BIN" --test tests/contracts/*.test.mjs
bash tool/security_static_scan.sh

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  echo "STAGING DEPLOYMENT CHECK PASSED — NO DEPLOYMENT PERFORMED"
  exit 0
fi

echo "===== LIVE STAGING DEPLOYMENT ====="
echo "Target project: $STAGING_PROJECT_ID"
echo "Component:      $COMPONENT"

"$FIREBASE_BIN" deploy \
  --project "$STAGING_PROJECT_ID" \
  --only "$COMPONENT"

echo "STAGING DEPLOYMENT COMPLETE"
