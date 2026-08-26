#!/usr/bin/env bash
# prose-budget-guard.sh — Surface the context cost of an instruction edit at the
# moment it is written.
#
# Every skill, command, and CLAUDE.md file under config/ is loaded into context
# on invocation, so prose there is paid for on every run — unlike product code,
# which is read on demand, and unlike $ARTIFACTS, which is never loaded at all.
# Nothing measured that cost before, and the feedback loops in this repo all
# produce more prose, so the corpus only grows.
#
# WARNS, NEVER DENIES. No hook can judge whether prose is load-bearing, and a
# new skill is legitimately 150 lines. The known weakness is that a warning can
# simply be ignored; that is what makes this measurable — if the corpus keeps
# growing at the same rate, warning was the wrong instrument.
#
# THREE EDIT ROUTES, TWO WAYS TO MEASURE. The Edit and Write tools carry the
# before and after text in the payload, so the per-edit delta is exact. A Bash
# command (sed -i, a heredoc, tee) carries an arbitrary shell string that cannot
# be projected, so that route falls back to git: cumulative uncommitted added
# lines for the corpus. Both numbers are honest about which one they are.
#
# Matching Bash is not optional. Under `permissions.defaultMode = "auto"` the
# harness instructs the model to make file changes through Bash wherever it can,
# so a Write|Edit-only matcher misses the dominant route in the mode this
# machine actually runs.

set -uo pipefail

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // "."')

# The corpus: instruction prose that is loaded into context, identified by its
# path rather than its content.
CORPUS_RE='modules/home/claude/config/[^ "'"'"';|&)]*\.md'
THRESHOLD=10

# Resolve the repo root from a matched corpus path so this works from any
# worktree, and without hardcoding a checkout location.
# The corpus path may arrive absolute (Edit/Write always do) or relative to the
# session cwd (a shell command usually does), so strip the suffix WITHOUT
# requiring a leading slash — anchoring on "/modules/..." silently matches
# nothing on a relative path and yields the file itself as the root.
corpus_root() {
  local prefix="${1%%modules/home/claude/config/*}"
  prefix="${prefix%/}"
  case "$prefix" in
    "") printf '%s' "$CWD" ;;
    /*) printf '%s' "$prefix" ;;
    *)  printf '%s' "$CWD/$prefix" ;;
  esac
}

corpus_lines() {
  find "$1/modules/home/claude/config" -name '*.md' -exec cat {} + 2>/dev/null | wc -l | tr -d ' '
}

warn() {
  jq -n --arg m "$1" '{
    systemMessage: $m,
    hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $m}
  }'
  exit 0
}

case "$TOOL" in
  Edit | Write)
    FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
    printf '%s' "$FILE" | grep -qE "$CORPUS_RE\$" || exit 0

    if [ "$TOOL" = Edit ]; then
      ADDED=$(printf '%s' "$INPUT" | jq -r '
        ((.tool_input.new_string // "") | split("\n") | length)
        - ((.tool_input.old_string // "") | split("\n") | length)')
    else
      NEW=$(printf '%s' "$INPUT" | jq -r '(.tool_input.content // "") | split("\n") | length')
      OLD=$(wc -l < "$FILE" 2>/dev/null | tr -d ' ')
      ADDED=$((NEW - ${OLD:-0}))
    fi

    [ "$ADDED" -gt "$THRESHOLD" ] 2>/dev/null || exit 0

    ROOT=$(corpus_root "$FILE")
    BEFORE=$(corpus_lines "$ROOT")
    warn "This edit adds $ADDED lines to $(basename "$FILE"), a file loaded into context on every invocation. Corpus: $BEFORE → $((BEFORE + ADDED)) lines. Not a rule — just the bill."
    ;;

  Bash)
    CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
    [ -z "$CMD" ] && exit 0

    # One cheap grep gates everything below, so ordinary Bash calls — the vast
    # majority — pay a single pattern match and exit.
    HIT=$(printf '%s' "$CMD" | grep -oE "$CORPUS_RE" | head -1)
    [ -z "$HIT" ] && exit 0

    # Reading about the corpus is not editing it. Gate on the presence of a
    # WRITE, not on whether the leading command looks read-only: 139 of the
    # corpus-touching Bash calls in the archive open with `cd <dir> &&`, so the
    # leading token is `cd` and says nothing about what follows.
    printf '%s' "$CMD" \
      | grep -qE 'sed[[:space:]]+-i|>>?[[:space:]]*[^ &|]|<<|tee[[:space:]]|(python3?|perl|ruby)[[:space:]]|cp[[:space:]]|mv[[:space:]]|truncate[[:space:]]' \
      || exit 0

    ROOT=$(corpus_root "$HIT")
    CONFIG="$ROOT/modules/home/claude/config"
    git -C "$ROOT" rev-parse --git-dir &>/dev/null || exit 0

    # Tracked adds since HEAD, plus every line of a file git does not know about
    # yet — a new skill starts untracked, so numstat alone would score it zero.
    TRACKED=$(git -C "$ROOT" diff --numstat -- "$CONFIG" 2>/dev/null \
      | awk '$1 ~ /^[0-9]+$/ && $3 ~ /\.md$/ {s += $1} END {print s + 0}')
    # Counted in a loop rather than via xargs: `xargs -r` is not portable, and
    # without it an empty file list makes `cat` read stdin and hang the hook.
    UNTRACKED=0
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      n=$(wc -l < "$ROOT/$f" 2>/dev/null | tr -d ' ')
      UNTRACKED=$((UNTRACKED + ${n:-0}))
    done < <(git -C "$ROOT" ls-files --others --exclude-standard -- "$CONFIG" 2>/dev/null \
             | grep -E '\.md$')
    ADDED=$((TRACKED + UNTRACKED))

    [ "$ADDED" -gt "$THRESHOLD" ] 2>/dev/null || exit 0

    TOTAL=$(corpus_lines "$ROOT")
    warn "Uncommitted corpus growth is +$ADDED lines across instruction files loaded into context on every invocation (corpus now $TOTAL lines). This edit route is a shell command, so its own delta is not projectable — the figure is cumulative since HEAD. Not a rule — just the bill."
    ;;
esac

exit 0
