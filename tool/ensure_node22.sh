#!/usr/bin/env bash
# Source this file from another Polycircle development script. It may update PATH
# or initialize nvm in the current shell process.

polycircle_node_major() {
  command -v node >/dev/null 2>&1 || return 1
  node -p "process.versions.node.split('.')[0]" 2>/dev/null
}

if [[ "$(polycircle_node_major || true)" != "22" ]]; then
  if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    # shellcheck disable=SC1090
    . "$HOME/.nvm/nvm.sh"
    nvm use 22 >/dev/null 2>&1 || nvm install 22 >/dev/null
  elif command -v brew >/dev/null 2>&1 && brew --prefix node@22 >/dev/null 2>&1; then
    NODE22_PREFIX="$(brew --prefix node@22)"
    export PATH="$NODE22_PREFIX/bin:$PATH"
  fi
fi

if [[ "$(polycircle_node_major || true)" != "22" ]]; then
  printf "✗ Node 22 is required for Polycircle Functions, but it is not available.\n" >&2
  printf "  Install Node 22 (for example with nvm or Homebrew node@22), then retry.\n" >&2
  return 1 2>/dev/null || exit 1
fi
