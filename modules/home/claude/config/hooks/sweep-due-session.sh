#!/usr/bin/env bash
#
# sweep-due-session.sh — surface an overdue skill sweep where the work happens.
#
# A desktop banner needs the user present at 09:00 Monday. This catches them at
# the next session instead, from any repo and any host, which is the only channel
# that reaches someone who was away on run day.
#
# It decides NOTHING. sweep-due.sh owns the decision and records it; this reads
# the last line. Deciding here would cost a full pass over the transcript
# archive — roughly eight seconds — on every session start, which is not a price
# a session-start hook may charge.

set -uo pipefail

# --selftest drives this script's real entry point against a throwaway
# XDG_STATE_HOME, so every case reads state this block wrote rather than the
# live record. Hermetic on purpose: the once-a-day guard is itself state, and a
# test sharing the real directory would pass or fail on whether a session had
# already opened today.
#
# A mistyped flag would otherwise fall through to the hook body, read the real
# state and exit 0 — silence that reads as a pass. Reject it loudly. A hook
# invocation passes no arguments at all, so this cannot affect the live path.
if [ -n "${1:-}" ] && [ "$1" != --selftest ]; then
  echo "unknown argument: $1 (the only flag is --selftest)" >&2
  exit 2
fi

if [ "${1:-}" = --selftest ]; then
  SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
  # `mktemp -d` with no template ignores TMPDIR on macOS and lands in a path the
  # Claude Code sandbox denies — so the bare form fails exactly where this is
  # most likely to be run.
  TMP=""
  for base in "${TMPDIR:-}" /tmp /private/tmp; do
    [ -n "$base" ] && [ -d "$base" ] || continue
    TMP=$(mktemp -d "$base/sweep-due-XXXXXX" 2>/dev/null) && break
  done
  [ -n "$TMP" ] || {
    echo "selftest: no writable temp directory" >&2
    exit 1
  }
  trap 'rm -rf "$TMP"' EXIT
  command -v jq >/dev/null 2>&1 || {
    echo "selftest: jq is required" >&2
    exit 1
  }

  day() { date -v-"$1"d +%Y-%m-%d 2>/dev/null || date -d "$1 days ago" +%Y-%m-%d 2>/dev/null; }
  line() { printf '%sT09:00:00\t%s\t%s' "$1" "$2" "$3"; }

  pass=0 fail=0
  # One XDG_STATE_HOME and one artifacts root per case. The daily SEEN guard
  # would otherwise silence every case after the first, and they would all
  # "pass" as silent. The two roots are separate in production too: the marker
  # lives under the artifacts root because a Claude Code session can write there
  # and cannot write XDG state at all.
  run() { # $1 = state body ("" for no file), $2 = marker date ("" for none)
    # mktemp, not a counter: run is called inside $(...), so a counter increments
    # in a subshell and every case silently reuses the first case's directory —
    # and its SEEN marker, which makes the rest of the suite pass as silent.
    local home dir
    home=$(mktemp -d "$TMP/case-XXXXXX")
    dir="$home/claude"
    mkdir -p "$dir"
    [ -n "$1" ] && printf '%s\n' "$1" >"$dir/sweep-due.state"
    [ -n "$2" ] && {
      mkdir -p "$home/artifacts/skill-reviewer"
      printf '%s' "$2" >"$home/artifacts/skill-reviewer/sweep-due.ran"
    }
    XDG_STATE_HOME="$home" MY_AGENT_ARTIFACTS_ROOT="$home/artifacts" bash "$SELF" 2>/dev/null |
      jq -r '.systemMessage // empty' 2>/dev/null
  }
  check() { # desc, warn|silent, state, marker, [substring the message must hold]
    local desc="$1" expect="$2" want="${5:-}" out got
    out=$(run "$3" "$4")
    if [ -n "$out" ]; then got=warn; else got=silent; fi
    if [ "$got" = "$expect" ] && { [ -z "$want" ] || case "$out" in *"$want"*) true ;; *) false ;; esac } then
      pass=$((pass + 1))
      printf '  ok    %s\n' "$desc"
    else
      fail=$((fail + 1))
      printf '  FAIL  %s (expected %s%s, got %s: %s)\n' \
        "$desc" "$expect" "${want:+ containing \"$want\"}" "$got" "${out:-<silence>}"
    fi
  }

  D7=$(day 7)
  D8=$(day 8)
  D6=$(day 6)
  D18=$(day 18)
  D20=$(day 20)
  D2=$(day 2)
  TODAY=$(day 0)
  DUE7=$(line "$D7" DUE "11 days since the last /system-review ($D18)")

  echo "Verdict:"
  check "DUE with no sweep since is announced" warn "$DUE7" ""
  check "NOT-DUE stays silent" silent "$(line "$D2" NOT-DUE "2 days since the last /system-review ($D2)")" ""
  check "no state file stays silent" silent "" ""

  echo "Marker retires a satisfied verdict:"
  check "a sweep run after the verdict retires it" silent "$DUE7" "$D6"
  check "a sweep run the same day retires it" silent "$DUE7" "$D7"
  check "a sweep run before the verdict does not" warn "$DUE7" "$D8"

  echo "Honesty about the verdict's age:"
  check "the message dates the verdict it replays" warn "$DUE7" "" "verdict from $D7"

  echo "Staleness outranks the marker:"
  # A hand-run sweep says nothing about whether the scheduled agent still fires,
  # so it must not silence the branch that reports a dead one.
  check "stale-agent warning ignores the marker" warn \
    "$(line "$D20" DUE "31 days since the last /system-review ($(day 51))")" "$TODAY" "may not be firing"

  echo "Once a day:"
  # MY_AGENT_ARTIFACTS_ROOT is pinned here too, not just in run(). Without it
  # this case read the real marker, and the suite went from green to red the
  # moment a live sweep was recorded — a test that passes only on a machine
  # that has never run the thing under test.
  H="$TMP/seen"
  mkdir -p "$H/claude" "$H/artifacts"
  printf '%s\n' "$DUE7" >"$H/claude/sweep-due.state"
  seen_run() { XDG_STATE_HOME="$H" MY_AGENT_ARTIFACTS_ROOT="$H/artifacts" \
    bash "$SELF" 2>/dev/null | jq -r '.systemMessage // empty'; }
  first=$(seen_run)
  second=$(seen_run)
  if [ -n "$first" ] && [ -z "$second" ]; then
    pass=$((pass + 1))
    printf '  ok    %s\n' "the second session the same day is silent"
  else
    fail=$((fail + 1))
    printf '  FAIL  %s (first=%s second=%s)\n' \
      "the second session the same day is silent" "${first:-<silence>}" "${second:-<silence>}"
  fi

  echo "Argument handling:"
  if bash "$SELF" --nonsense >/dev/null 2>&1; then
    fail=$((fail + 1))
    printf '  FAIL  %s\n' "an unknown flag is rejected, not silently ignored"
  else
    pass=$((pass + 1))
    printf '  ok    %s\n' "an unknown flag is rejected, not silently ignored"
  fi

  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]
  exit $?
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude"
STATE="$STATE_DIR/sweep-due.state"
SEEN="$STATE_DIR/sweep-due.seen"

# No record at all: stay silent. Absence means the weekly agent has not run here
# yet — a fresh machine, a new install, or simply no Monday since. Speaking up
# would repeat the exact defect this work fixed: a host raising a banner about
# state it does not have and cannot satisfy.
[ -f "$STATE" ] || exit 0

LINE=$(tail -1 "$STATE" 2>/dev/null) || exit 0
[ -n "$LINE" ] || exit 0

WHEN=${LINE%%$'\t'*}
REST=${LINE#*$'\t'}
DECISION=${REST%%$'\t'*}
REASON=${REST#*$'\t'}
DAY=${WHEN%%T*}

# Under the artifacts root, NOT beside STATE in XDG state — and that is a
# runtime constraint, not a preference. `/system-review` runs inside a Claude
# Code session, whose sandbox allows writes only to the roots in
# modules/home/agents/boundary.nix; XDG state is not one of them, so a marker
# written there is refused with "Operation not permitted" and the mark silently
# never happens. The artifacts root is already this skill's own state directory
# (LEDGER.md lives there) and is writable from a session.
#
# It also keeps STATE unwritable from inside a session, which is what makes the
# staleness branch below trustworthy: that branch reads STATE's timestamp to
# tell a late scheduled agent from a dead one, and nothing a session does can
# forge it. Same resolution order as sweep-due.sh --ran; change both together.
RAN_DAY=$(cat "${MY_AGENT_ARTIFACTS_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/agents/artifacts}/skill-reviewer/sweep-due.ran" 2>/dev/null)

epoch() {
  date -j -f '%Y-%m-%d %H:%M:%S' "$1 00:00:00" +%s 2>/dev/null ||
    date -d "$1 00:00:00" +%s 2>/dev/null
}

TODAY=$(date +%Y-%m-%d)
NOW=$(epoch "$TODAY")
THEN=$(epoch "$DAY")
AGE=0
[ -n "$NOW" ] && [ -n "$THEN" ] && AGE=$(((NOW - THEN) / 86400))

# At most once a day. Ten sessions in an afternoon is ten identical reminders,
# which is how a useful signal becomes one people learn to skip.
[ "$(cat "$SEEN" 2>/dev/null)" = "$TODAY" ] && exit 0

emit() {
  mkdir -p "$STATE_DIR" 2>/dev/null && printf '%s' "$TODAY" >"$SEEN" 2>/dev/null
  jq -n --arg m "$1" '{
    systemMessage: $m,
    hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $m}
  }'
  exit 0
}

command -v jq >/dev/null 2>&1 || exit 0

# A record that has stopped advancing means the scheduled agent is no longer
# firing. That is a defect in the instrument, and it outranks whatever the stale
# line happens to say. Two weeks is a missed fortnightly window, not a late one.
if [ "$AGE" -gt 14 ]; then
  emit "Skill sweep check is stale: the last recorded run was $DAY ($AGE days ago). The scheduled agent may not be firing — check the launchd/systemd unit for claude-sweep-due."
fi

# Suppressed by the marker, but only here — the staleness branch above stays
# unconditional, because a sweep run by hand says nothing about whether the
# scheduled agent is still firing. ISO dates compare correctly as strings.
#
# The date is in the message because the verdict is a replay, not a fresh
# reading: REASON carries an age computed when the agent wrote the line, and it
# does not advance as the week does. Saying which day it was decided is what
# keeps a stale-but-unsatisfied verdict honest.
if [ "$DECISION" = "DUE" ] && { [ -z "$RAN_DAY" ] || [[ "$RAN_DAY" < "$DAY" ]]; }; then
  emit "Skill sweep is due (verdict from $DAY): $REASON. Run /system-review when convenient — it reports what crossed threshold and stops."
fi

exit 0
