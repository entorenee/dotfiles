#!/usr/bin/env bash
# exec-form-guard.sh — Enforce the documented *form* for running project binaries.
#
# The rule is already written in CLAUDE.md, but a 2026-07-28 permission audit
# found 167 auto-mode calls that violated it by invoking a binary through its
# relative node_modules/.bin/ path. Auto mode never surfaced a prompt for any of
# them, so the written rule got no corrective feedback. This hook makes it
# mechanical instead of advisory.
#
#   node_modules/.bin/<bin>  → use `pnpm exec <bin>` (or `npx <bin>`).
#   Both are allowlisted; the .bin path matches no allow pattern, so it prompts
#   every time in any mode stricter than auto.
#
# A glob in `permissions.ask` cannot express this rule. Ask rules handle the
# `cd … &&` and env-prefix shapes by themselves, but they match a subcommand
# from its start, and these arrive as `../node_modules/.bin/tsc` — so the
# pattern needs a leading `*`, and the binary name varies, so it needs a
# trailing one too. `Bash(*node_modules/.bin/*)` then matches an unquoted
# `grep -rn node_modules/.bin/tsc .`, which is a search, not an execution. The
# read-only-inspector bypass below is the part a glob has no way to say, and it
# is why this rule lives here and not in settings.
#
# Inline interpreter forms (`python3 -c`, `node -e`, `node -p`) are NOT here.
# They are `permissions.ask` rules in modules/home/claude/default.nix. Do not
# re-add them: an ask rule is subcommand-anchored, so it already reaches into
# `&&` chains, `$( )` and env prefixes, and a quoted argument naming the form is
# not a subcommand and so cannot false-positive — which the regex that used to
# live here did, twice, on its own author.
#
# `--selftest` asserts the decisions. The allow half is the load-bearing half:
# listing the directory and grepping for a path are legitimate, and a guard that
# blocks them is worse than one that is narrow.

if ! command -v jq &>/dev/null; then
  exit 0
fi

# A mistyped flag, or a DEPLOYED copy predating this block, otherwise falls
# through to the hook body, reads empty stdin and exits 0 — silence that reads
# as a pass. A hook invocation passes no arguments at all, so rejecting an
# unrecognised one cannot affect the live path.
if [ -n "${1:-}" ] && [ "$1" != --selftest ]; then
  echo "unknown argument: $1 (the only flag is --selftest)" >&2
  exit 2
fi

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

# Quoted spans collapse to one placeholder token before matching, so a command
# that merely *names* the path inside an argument cannot reach the rule through
# it. This covers the shapes the first-token check below cannot: in
# `cd app && grep -rn "node_modules/.bin/tsc" .` the first token is `cd`, so
# without masking that search reads as an execution.
mask() {
  sed -e "s/'[^']*'/Q/g" -e 's/"[^"]*"/Q/g'
}

# Requiring a binary name after the slash is what keeps a bare
# `ls node_modules/.bin/` from matching.
BIN_RE='node_modules/\.bin/[A-Za-z0-9_@.-]+'

if [ "${1:-}" = --selftest ]; then
  SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")

  pass=0
  fail=0
  # expect: "deny" or "allow"; extra arg = substring the reason must contain.
  # The probe command is only ever a JSON string — nothing here executes it.
  check() {
    local desc="$1" expect="$2" cmd="$3" want="${4:-}" out got reason
    out=$(jq -n --arg c "$cmd" '{tool_input:{command:$c}}' | bash "$SELF" 2>/dev/null)
    if [ -z "$out" ]; then
      got=allow
      reason=""
    else
      got=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "malformed"' 2>/dev/null)
      reason=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)
    fi
    if [ "$got" = "$expect" ] && { [ -z "$want" ] || case "$reason" in *"$want"*) true ;; *) false ;; esac } then
      pass=$((pass + 1))
      printf '  ok    %s\n' "$desc"
    else
      fail=$((fail + 1))
      printf '  FAIL  %s (expected %s%s, got %s: %s)\n' \
        "$desc" "$expect" "${want:+ containing \"$want\"}" "$got" "${reason:-<silence>}"
    fi
  }

  echo "Executing a binary by its .bin path (deny):"
  check "relative .bin path" deny "../node_modules/.bin/tsc --noEmit" "pnpm exec tsc"
  check "bare .bin path" deny "node_modules/.bin/jest --ci" "pnpm exec jest"
  check ".bin path behind an env var" deny "NODE_OPTIONS=--trace node_modules/.bin/jest" "pnpm exec jest"
  check ".bin path after a cd" deny "cd app && node_modules/.bin/eslint src" "pnpm exec eslint"
  check "scoped binary name" deny "node_modules/.bin/@scope-cli build" "pnpm exec @scope-cli"

  echo "Reading about the path rather than running it (allow):"
  check "listing the .bin directory" allow "ls node_modules/.bin/"
  check "grepping for a .bin path" allow "grep -rn node_modules/.bin/tsc ."
  check "quoted path behind a cd" allow "cd app && grep -rn \"node_modules/.bin/tsc\" ."
  check "single-quoted path in prose" allow "echo 'use node_modules/.bin/tsc'"
  check "find naming the directory" allow "find . -path \"*node_modules/.bin/tsc\""
  check "the allowlisted form" allow "pnpm exec tsc --noEmit"

  printf '\n%s passed, %s failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ] || exit 1
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

MASKED=$(printf '%s\n' "$CMD" | mask)

# The search is deliberately unanchored — no "start of the command" requirement.
# These paths routinely carry an env prefix (NODE_OPTIONS='...'
# ../node_modules/.bin/tsc) or follow a `cd … &&`, so anchoring would miss the
# common shapes.
if echo "$MASKED" | grep -qE "$BIN_RE"; then
  # An unquoted path handed to a read-only inspector survives masking, so the
  # first token is still checked: `grep -rn node_modules/.bin/tsc .` is a search.
  FIRST=$(echo "$CMD" | sed -E 's/^[[:space:]]*//' | head -1 | awk '{print $1}')
  case "$FIRST" in
  grep | rg | egrep | fgrep | ls | find | fd | cat | head | tail | echo | printf | stat | readlink | wc)
    exit 0
    ;;
  esac

  BIN=$(echo "$MASKED" | grep -oE "$BIN_RE" | head -1 | sed -E 's|.*/||')
  deny "Invoking '$BIN' by its node_modules/.bin/ path matches no allow pattern, so it prompts every time. Use 'pnpm exec $BIN' or 'npx $BIN' instead — both are allowlisted."
fi

exit 0
