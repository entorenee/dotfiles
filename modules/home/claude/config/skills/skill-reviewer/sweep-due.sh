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

# inventory.sh hard-fails when MY_CLAUDE_ARTIFACTS_ROOT is unset, which is the
# default for a launchd agent. Its failure and "the sweep has never run" both
# produce no output, and they call for opposite responses — so separate them
# here rather than notifying on a number that was never read.
INV_OUT=$(bash "$INVENTORY" --json 2>&1)
INV_RC=$?
if [ "$INV_RC" -ne 0 ]; then
  echo "sweep-due: inventory.sh failed (rc=$INV_RC): $(printf '%s' "$INV_OUT" | head -1)" >&2
  exit 2
fi

LAST=$(printf '%s' "$INV_OUT" \
  | jq -r '(.units[]? | select(.unit=="system-review") | .last_run) // empty' 2>/dev/null | head -1)

NOW=$(epoch "$(date +%Y-%m-%d)")
if [ -z "$LAST" ] || [ "$LAST" = null ]; then
  # Never recorded. Due by definition, and say which case it is rather than
  # reporting a fabricated age.
  AGE=""
  REASON="/system-review has no recorded run"
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
    exit 0
  fi
fi

if [ "$MODE" = check ]; then
  echo "DUE: $REASON (threshold ${THRESHOLD}d)"
  exit 0
fi

TITLE="Skill sweep due"
BODY="$REASON. Run /system-review."

# Same mechanism and fallback order as notify-attention.sh: terminal-notifier
# when present, osascript otherwise, notify-send on Linux.
if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier -title "$TITLE" -message "$BODY" -sound Ping >/dev/null 2>&1 || true
elif command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$BODY\" with title \"$TITLE\" sound name \"Ping\"" \
    >/dev/null 2>&1 || true
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "$TITLE" "$BODY" >/dev/null 2>&1 || true
fi

exit 0
