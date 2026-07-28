#!/usr/bin/env bash
# exec-form-guard.sh — Enforce the documented *form* for running project
# binaries and for inspecting files.
#
# Both rules below are already written in CLAUDE.md, but a 2026-07-28
# permission audit found 304 auto-mode calls that violated them: 167 relative
# node_modules/.bin/ invocations and 137 inline `node -e` / `python3 -c` calls.
# Auto mode never surfaced a prompt for any of them, so the written rules got
# no corrective feedback. This hook makes them mechanical instead of advisory.
#
#   1. node_modules/.bin/<bin>  → use `pnpm exec <bin>` (or `npx <bin>`).
#      Both are allowlisted; the .bin path matches no allow pattern, so it
#      prompts every time in any mode stricter than auto.
#   2. node -e / python -c      → use the Read tool. Arbitrary code execution
#      cannot be allowlisted by design, so these always prompt.

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

deny() {
  jq -n --arg reason "$1" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": $reason
    }
  }'
  exit 0
}

# A command position is the start of a line, or just after ; & | or (. grep
# works line by line, so "^" also covers newline-separated commands. Anchoring
# this way keeps matches out of quoted strings and heredoc prose — an
# unanchored match reports `grep -rn 'node -e'` as a violation.
CMD_POS='(^|[;&|(])[[:space:]]*'

# Rule 2 — inline interpreter execution.
if echo "$CMD" | grep -qE "${CMD_POS}node[[:space:]]+(-e|--eval)([[:space:]]|$)"; then
  deny "node -e is denied: arbitrary code execution can't be allowlisted, so it prompts in every mode. To inspect a file (package.json, a lockfile, any config) use the Read tool. To run a project binary use 'pnpm exec <bin>'."
fi

if echo "$CMD" | grep -qE "${CMD_POS}python3?[[:space:]]+-c([[:space:]]|$)"; then
  deny "python -c is denied: arbitrary code execution can't be allowlisted, so it prompts in every mode. Use the Read tool to inspect files."
fi

# Rule 1 — project binaries invoked by path.
#
# Deliberately NOT anchored to a command position: these routinely carry an env
# prefix (NODE_OPTIONS='...' ../node_modules/.bin/tsc) or follow a "cd ... &&",
# so anchoring would miss the common shapes. Requiring a binary name after the
# slash keeps a bare `ls node_modules/.bin/` from matching, and the read-only
# inspector check below covers the rest.
BIN_RE='node_modules/\.bin/[A-Za-z0-9_@.-]+'

if echo "$CMD" | grep -qE "$BIN_RE"; then
  # Passing through when the command merely *reads about* the path (grepping
  # for it, listing it) rather than executing it.
  FIRST=$(echo "$CMD" | sed -E 's/^[[:space:]]*//' | head -1 | awk '{print $1}')
  case "$FIRST" in
    grep | rg | egrep | fgrep | ls | find | fd | cat | head | tail | echo | printf | stat | readlink | wc)
      exit 0
      ;;
  esac

  BIN=$(echo "$CMD" | grep -oE "$BIN_RE" | head -1 | sed -E 's|.*/||')
  deny "Invoking '$BIN' by its node_modules/.bin/ path matches no allow pattern, so it prompts every time. Use 'pnpm exec $BIN' or 'npx $BIN' instead — both are allowlisted."
fi

exit 0
