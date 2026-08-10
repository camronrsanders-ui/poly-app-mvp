#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() { printf '✗ %s\n' "$1" >&2; exit 1; }
ok() { printf '✓ %s\n' "$1"; }

command -v git >/dev/null 2>&1 || fail "git is required for the repository security scan."
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || fail "Run this security scan from a Git checkout."

tracked_sensitive="$(
  git ls-files \
    | grep -E '(^|/)(GoogleService-Info\.plist|google-services\.json|firebase_options\.dart|\.env($|\.)|[^/]*service[-_]?account[^/]*\.json|[^/]*\.p8|[^/]*\.p12|[^/]*\.jks|[^/]*\.keystore|[^/]*\.mobileprovision)$' \
    | grep -Ev '(^|/)\.env\.example$' \
    || true
)"
if [[ -n "$tracked_sensitive" ]]; then
  printf '%s\n' "$tracked_sensitive" >&2
  fail "Environment-specific Firebase/signing/secret material is tracked by git."
fi
ok "no environment-specific Firebase or signing files are tracked"

if git grep -n -E 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' -- ':!tool/security_static_scan.sh' >/tmp/polycircle-secret-scan.txt 2>/dev/null; then
  cat /tmp/polycircle-secret-scan.txt >&2
  rm -f /tmp/polycircle-secret-scan.txt
  fail "Private-key material appears in tracked repository content."
fi
rm -f /tmp/polycircle-secret-scan.txt
ok "no PEM private-key markers found"

if git grep -n -E '"private_key"[[:space:]]*:' -- ':!tool/security_static_scan.sh' >/tmp/polycircle-service-account-scan.txt 2>/dev/null; then
  cat /tmp/polycircle-service-account-scan.txt >&2
  rm -f /tmp/polycircle-service-account-scan.txt
  fail "Service-account private-key data appears in tracked repository content."
fi
rm -f /tmp/polycircle-service-account-scan.txt
ok "no service-account private-key fields found"

# Debug App Check tokens and native debug launch flags must never become part of
# a committed app build. Documentation can describe the workflow separately.
for scope in lib ios android functions; do
  [[ -e "$scope" ]] || continue
  if git grep -n 'FIREBASE_APP_CHECK_DEBUG_TOKEN' -- "$scope" >/tmp/polycircle-appcheck-scan.txt 2>/dev/null; then
    cat /tmp/polycircle-appcheck-scan.txt >&2
    rm -f /tmp/polycircle-appcheck-scan.txt
    fail "An App Check debug-token variable is present in tracked application/runtime code."
  fi
done
rm -f /tmp/polycircle-appcheck-scan.txt
ok "no App Check debug-token value is committed in runtime code"

if [[ -d ios ]] && git grep -n -- '-FIRDebugEnabled' -- ios >/tmp/polycircle-ios-debug-scan.txt 2>/dev/null; then
  cat /tmp/polycircle-ios-debug-scan.txt >&2
  rm -f /tmp/polycircle-ios-debug-scan.txt
  fail "FIRDebugEnabled is committed under ios/. Keep it local to simulator development."
fi
rm -f /tmp/polycircle-ios-debug-scan.txt
ok "no committed iOS Firebase debug launch flag found"

# Polycircle intentionally denies direct client Storage SDK access. Uploads and
# delivery use trusted Functions plus short-lived signed URLs instead.
if git grep -n -E "package:firebase_storage|FirebaseStorage\.instance|firebase_storage:" -- lib pubspec.yaml >/tmp/polycircle-storage-sdk-scan.txt 2>/dev/null; then
  cat /tmp/polycircle-storage-sdk-scan.txt >&2
  rm -f /tmp/polycircle-storage-sdk-scan.txt
  fail "Direct Firebase Storage client usage was introduced; protected-media architecture requires trusted delivery."
fi
rm -f /tmp/polycircle-storage-sdk-scan.txt
ok "no direct Firebase Storage client SDK path found"

printf '\nRepository security static scan passed.\n'
