#!/usr/bin/env bash
# pnpm-guard.sh — Block write-mode `npm` commands when the repo uses pnpm.
#
# Walks up from $PWD looking for pnpm-lock.yaml. If found and the command
# is a write-mode npm op (install/add/ci/etc.), emit a deny decision with
# the suggested pnpm equivalent. Read-only npm ops (ls, view, etc.) and
# repos without a pnpm lockfile are passed through unchanged.

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

# Strip leading whitespace and optional "cd ... &&" prefix so we detect npm
# in commands like `cd packages/foo && npm install`.
NORMALIZED=$(echo "$CMD" | sed -E 's/^[[:space:]]*//;s/^cd [^&]+&&[[:space:]]*//')

if ! echo "$NORMALIZED" | grep -qE '^npm[[:space:]]+(install|i|add|ci|uninstall|un|remove|rm|update|up)([[:space:]]|$)'; then
  exit 0
fi

# Walk up from PWD to find pnpm-lock.yaml.
DIR=$PWD
LOCKFILE=""
while [ "$DIR" != "/" ]; do
  if [ -f "$DIR/pnpm-lock.yaml" ]; then
    LOCKFILE="$DIR/pnpm-lock.yaml"
    break
  fi
  DIR=$(dirname "$DIR")
done

[ -z "$LOCKFILE" ] && exit 0

# Suggest the pnpm equivalent.
PNPM_EQUIV=$(echo "$NORMALIZED" | sed -E '
  s/^npm install$/pnpm install/;
  s/^npm install /pnpm add /;
  s/^npm i$/pnpm install/;
  s/^npm i /pnpm add /;
  s/^npm add /pnpm add /;
  s/^npm ci.*$/pnpm install --frozen-lockfile/;
  s/^npm uninstall /pnpm remove /;
  s/^npm un /pnpm remove /;
  s/^npm remove /pnpm remove /;
  s/^npm rm /pnpm remove /;
  s/^npm update/pnpm update/;
  s/^npm up$/pnpm update/;
  s/^npm up /pnpm update /
')

REASON="pnpm-lock.yaml found at $LOCKFILE — this repo uses pnpm. Use: $PNPM_EQUIV"

jq -n --arg reason "$REASON" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": $reason
  }
}'
