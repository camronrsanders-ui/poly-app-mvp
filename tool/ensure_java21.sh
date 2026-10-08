#!/usr/bin/env bash
set -euo pipefail

# This file is intended to be sourced so JAVA_HOME/PATH remain active in the
# caller that later launches Firebase emulators. macOS ships /usr/bin/java as a
# launcher shim even when no JDK is registered, so command -v java alone is not
# a sufficient readiness check.

polycircle_java_major() {
  local output first
  output="$(java -version 2>&1)" || return 1
  first="${output%%$'\n'*}"
  printf '%s' "$first" | sed -E 's/.*version "([0-9]+).*/\1/'
}

polycircle_java_is_compatible() {
  local major
  major="$(polycircle_java_major 2>/dev/null || true)"
  [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 21 ))
}

if polycircle_java_is_compatible; then
  return 0 2>/dev/null || exit 0
fi

# Homebrew's openjdk@21 is keg-only. Prefer it when installed and export the
# environment into the current shell so Firebase CLI subprocesses inherit it.
if command -v brew >/dev/null 2>&1; then
  JAVA21_PREFIX="$(brew --prefix openjdk@21 2>/dev/null || true)"
  if [[ -n "$JAVA21_PREFIX" && -x "$JAVA21_PREFIX/bin/java" ]]; then
    export JAVA_HOME="$JAVA21_PREFIX/libexec/openjdk.jdk/Contents/Home"
    export PATH="$JAVA21_PREFIX/bin:$PATH"
  fi
fi

if ! polycircle_java_is_compatible; then
  printf '✗ Java 21 or newer is required for Polycircle local Firebase emulators.\n' >&2
  printf '  On macOS with Homebrew: brew install openjdk@21\n' >&2
  printf '  Installed keg-only JDKs do not need a global symlink; this helper activates them per run.\n' >&2
  return 1 2>/dev/null || exit 1
fi
