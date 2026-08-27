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

epoch() {
  date -j -f '%Y-%m-%d %H:%M:%S' "$1 00:00:00" +%s 2>/dev/null \
    || date -d "$1 00:00:00" +%s 2>/dev/null
}

TODAY=$(date +%Y-%m-%d)
NOW=$(epoch "$TODAY"); THEN=$(epoch "$DAY")
AGE=0
[ -n "$NOW" ] && [ -n "$THEN" ] && AGE=$(( (NOW - THEN) / 86400 ))

# At most once a day. Ten sessions in an afternoon is ten identical reminders,
# which is how a useful signal becomes one people learn to skip.
[ "$(cat "$SEEN" 2>/dev/null)" = "$TODAY" ] && exit 0

emit() {
  mkdir -p "$STATE_DIR" 2>/dev/null && printf '%s' "$TODAY" > "$SEEN" 2>/dev/null
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

[ "$DECISION" = "DUE" ] && emit "Skill sweep is due: $REASON. Run /system-review when convenient — it reports what crossed threshold and stops."

exit 0
