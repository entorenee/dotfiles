#!/usr/bin/env bash
# pnpm-warm.sh — Warm pnpm for a freshly-switched worktree.
#
# Claude Code runs pnpm inside a network sandbox. When a repo pins a
# packageManager version (e.g. pnpm@10.33.0) that differs from the globally
# installed pnpm, every pnpm command triggers pnpm's package-manager
# self-switch, which downloads @pnpm/exe over the sandbox proxy. That download
# intermittently fails and — with pnpm's default pmOnFail=error — hard-aborts
# the command. Running `pnpm install` here, in the real shell on switch (no
# sandbox), pulls the pinned pnpm binary AND node_modules up front so
# in-sandbox commands hit a warm cache instead of the network.
#
# Only acts in pnpm repos; runs in the background so it never blocks the switch.

set -euo pipefail

WORKTREE="${1:-$PWD}"

# Only warm repos that actually use pnpm.
[ -f "$WORKTREE/pnpm-lock.yaml" ] || exit 0

# Nothing to warm if pnpm isn't installed.
command -v pnpm >/dev/null 2>&1 || exit 0

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/worktrunk"
mkdir -p "$LOG_DIR" 2>/dev/null || true
LOG="$LOG_DIR/pnpm-warm.log"

# Detach so the switch returns immediately; nohup survives the hook exiting.
nohup sh -c '
  cd "$1" || exit 0
  printf "\n=== pnpm install in %s (%s) ===\n" "$1" "$(date)"
  pnpm install
' _ "$WORKTREE" >>"$LOG" 2>&1 &

exit 0
