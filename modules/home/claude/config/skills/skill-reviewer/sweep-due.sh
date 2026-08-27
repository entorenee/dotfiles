#!/usr/bin/env bash
#
# sweep-due.sh — notify when /system-review is overdue.
#
#   bash sweep-due.sh              notify if overdue, silent otherwise
#   bash sweep-due.sh --check      print the decision, never notify
#   bash sweep-due.sh --threshold N   override the 7-day cadence
#
# Decides whether the sweep is due and says so. It does not run the sweep, read
# the transcripts, or write an artifact — and must not become a Claude session on
# a timer, which would write findings nobody asked for and report a failing
# selftest to a file rather than to a person.

set -uo pipefail

THRESHOLD=7
MODE=notify
while [ $# -gt 0 ]; do
  case "$1" in
    --check)     MODE=check ;;
    --threshold) THRESHOLD="${2:?--threshold needs a number}"; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

HERE="$(cd "$(dirname "$0")" && pwd)"
INVENTORY="$HERE/inventory.sh"
[ -f "$INVENTORY" ] || { echo "missing inventory.sh beside $0" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || exit 0

# BOTH ENDS PINNED TO MIDNIGHT. BSD `date -j -f '%Y-%m-%d'` fills the
# time-of-day from the clock at the moment it runs, so an age computed against
# an unpinned parse lands just under a whole number of days and integer
# division reports one day less. This bit the --aging arm already.
epoch() {
  date -j -f '%Y-%m-%d %H:%M:%S' "$1 00:00:00" +%s 2>/dev/null \
    || date -d "$1 00:00:00" +%s 2>/dev/null
}

# --------------------------------------------------------------------------
# Run record. Appended on EVERY run, whatever the outcome.
#
# Without it a fired banner, a failed banner, and a week the agent never ran are
# identical on disk — the script wrote nothing on success, and its stderr log
# stays absent when nothing errors.
#
# It is also what makes a session-start check cheap. Deciding this fresh costs a
# full inventory pass over the transcript archive, which is far too slow to run
# when a session opens; reading the last line here is free.
#
# Beside sweep-due.err, in a directory the module already creates.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude"
STATE="$STATE_DIR/sweep-due.state"
record() { # $1 = decision (DUE|NOT-DUE|ERROR), $2 = reason
  # Notify mode only — that is the scheduled path. `--check` is a manual query,
  # and a record written from one would forge evidence that the agent fired,
  # which is precisely what the staleness reader downstream is testing for.
  [ "$MODE" = notify ] || return 0
  mkdir -p "$STATE_DIR" 2>/dev/null || return 0
  printf '%s\t%s\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$1" "$2" >> "$STATE" 2>/dev/null || true
}

# `|| true` handles a non-zero exit, not a hang, and the notifier does hang —
# observed blocking past two minutes in a non-interactive context and needing a
# kill. macOS ships no `timeout`, so this is the portable form.
with_timeout() { # $1 = seconds, rest = command
  local secs="$1"; shift
  "$@" >/dev/null 2>&1 &
  local pid=$!
  ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local watchdog=$!
  wait "$pid" 2>/dev/null
  kill -TERM "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  return 0
}

# inventory.sh hard-fails when MY_CLAUDE_ARTIFACTS_ROOT is unset, which is the
# default for a launchd agent. Its failure and "the sweep has never run" both
# produce no output, and they call for opposite responses — so separate them
# here rather than notifying on a number that was never read.
INV_OUT=$(bash "$INVENTORY" --json 2>&1)
INV_RC=$?
if [ "$INV_RC" -ne 0 ]; then
  echo "sweep-due: inventory.sh failed (rc=$INV_RC): $(printf '%s' "$INV_OUT" | head -1)" >&2
  record ERROR "inventory.sh failed (rc=$INV_RC)"
  exit 2
fi

LAST=$(printf '%s' "$INV_OUT" \
  | jq -r '(.units[]? | select(.unit=="system-review") | .last_run) // empty' 2>/dev/null | head -1)

NOW=$(epoch "$(date +%Y-%m-%d)")
if [ -z "$LAST" ] || [ "$LAST" = null ]; then
  # Never recorded ON THIS MACHINE. `last_run` comes from this host's transcript
  # archive, which does not sync, so a host that has never run the sweep reports
  # null however many sweeps ran elsewhere — and the old wording, "/system-review
  # has no recorded run", stated that as a global fact. On a second machine it
  # made the banner fire every week with nothing that host could do to satisfy
  # it. Scope the claim to what the state actually covers.
  AGE=""
  REASON="/system-review has no recorded run on this machine"
else
  THEN=$(epoch "$LAST")
  if [ -z "$THEN" ] || [ -z "$NOW" ]; then
    echo "sweep-due: could not parse dates (last=$LAST)" >&2
    exit 2
  fi
  AGE=$(( (NOW - THEN) / 86400 ))
  REASON="$AGE days since the last /system-review ($LAST)"
  if [ "$AGE" -lt "$THRESHOLD" ]; then
    [ "$MODE" = check ] && echo "not due: $REASON (threshold ${THRESHOLD}d)"
    record NOT-DUE "$REASON"
    exit 0
  fi
fi

if [ "$MODE" = check ]; then
  echo "DUE: $REASON (threshold ${THRESHOLD}d)"
  exit 0
fi

# Recorded BEFORE the banner, not after. The notifier is the part that hangs, so
# a record written afterwards is exactly the record a hang loses.
record DUE "$REASON"

TITLE="Skill sweep due"
BODY="$REASON. Run /system-review."

# Same mechanism and fallback order as notify-attention.sh: terminal-notifier
# when present, osascript otherwise, notify-send on Linux.
if command -v terminal-notifier >/dev/null 2>&1; then
  with_timeout 10 terminal-notifier -title "$TITLE" -message "$BODY" -sound Ping
elif command -v osascript >/dev/null 2>&1; then
  with_timeout 10 osascript -e "display notification \"$BODY\" with title \"$TITLE\" sound name \"Ping\""
elif command -v notify-send >/dev/null 2>&1; then
  with_timeout 10 notify-send "$TITLE" "$BODY"
fi

exit 0
