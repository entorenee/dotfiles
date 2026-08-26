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

# --selftest builds a throwaway git repo with the corpus layout and drives this
# script's real entry point with synthetic payloads. Hermetic on purpose: the
# Bash branch reports growth since HEAD, so asserting against the live checkout
# would make results depend on whatever happens to be uncommitted.
#
# Every case here is one that shipped broken. A guard whose evidence is a
# transcript nobody re-runs is the failure it exists to prevent.
# A mistyped flag, or a DEPLOYED copy predating this block, otherwise falls
# through to the hook body, reads empty stdin and exits 0 — silence that reads
# as a pass. Reject anything unrecognised loudly instead. A hook invocation
# passes no arguments at all, so this cannot affect the live path.
if [ -n "${1:-}" ] && [ "$1" != --selftest ]; then
  echo "unknown argument: $1 (the only flag is --selftest)" >&2
  exit 2
fi

if [ "${1:-}" = --selftest ]; then
  SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
  # `mktemp -d` with no template ignores TMPDIR on macOS (it uses the Darwin
  # confstr temp dir), and that path is denied under the Claude Code sandbox —
  # so the bare form fails exactly where this is most likely to be run.
  TMP=""
  for base in "${TMPDIR:-}" /tmp /private/tmp; do
    [ -n "$base" ] && [ -d "$base" ] || continue
    TMP=$(mktemp -d "$base/prose-budget-XXXXXX" 2>/dev/null) && break
  done
  [ -n "$TMP" ] || { echo "selftest: no writable temp directory" >&2; exit 1; }
  trap 'rm -rf "$TMP"' EXIT
  CDIR="$TMP/modules/home/claude/config/skills/probe"
  mkdir -p "$CDIR"
  SK="$CDIR/SKILL.md"
  printf 'a\nb\nc\n' > "$SK"
  git -C "$TMP" init -q
  # Pin the excludes file: the untracked branch relies on --exclude-standard,
  # so a global ignore pattern matching *.md would silently zero that path and
  # the test would pass while measuring nothing.
  git -C "$TMP" config core.excludesFile /dev/null
  git -C "$TMP" add -A
  # The `add`/`commit` here are deliberate despite the global ban on both. That
  # rule protects the working tree's staging area as a human review marker; this
  # is a mktemp directory removed on exit, and the tracked-adds branch cannot be
  # covered without a HEAD. Do not replace it with plumbing to observe the
  # letter of the rule — decided 2026-08-26.
  #
  # commit.gpgsign is on globally and the signing key needs a physical touch, so
  # an inherited config makes this commit fail. It has to be turned off HERE, and
  # the failure has to be fatal: without a HEAD, `git diff --numstat` reports
  # nothing while ls-files reports everything as untracked, and the Bash-branch
  # cases pass for the wrong reason.
  if ! git -C "$TMP" -c user.email=t@t -c user.name=t -c commit.gpgsign=false \
       commit -qm base 2>/dev/null; then
    echo "selftest setup failed: could not create the baseline commit" >&2
    exit 1
  fi
  git -C "$TMP" rev-parse --verify -q HEAD >/dev/null || {
    echo "selftest setup failed: no HEAD after commit" >&2; exit 1; }

  pass=0; fail=0
  # expect: "warn" or "silent"; extra arg = substring the message must contain
  check() {
    local desc="$1" expect="$2" payload="$3" want="${4:-}" out got
    out=$(printf '%s' "$payload" | bash "$SELF" 2>/dev/null | jq -r '.systemMessage // empty' 2>/dev/null)
    if [ -n "$out" ]; then got=warn; else got=silent; fi
    if [ "$got" = "$expect" ] && { [ -z "$want" ] || case "$out" in *"$want"*) true ;; *) false ;; esac; }; then
      pass=$((pass + 1)); printf '  ok    %s\n' "$desc"
    else
      fail=$((fail + 1)); printf '  FAIL  %s (expected %s%s, got %s: %s)\n' \
        "$desc" "$expect" "${want:+ containing \"$want\"}" "$got" "${out:-<silence>}"
    fi
  }
  edit() { jq -n --arg f "$1" --arg o "$2" --arg n "$3" --arg c "$TMP" \
    '{tool_name:"Edit", cwd:$c, tool_input:{file_path:$f, old_string:$o, new_string:$n}}'; }
  write() { jq -n --arg f "$1" --arg n "$2" --arg c "$TMP" \
    '{tool_name:"Write", cwd:$c, tool_input:{file_path:$f, content:$n}}'; }
  bash_p() { jq -n --arg cmd "$1" --arg c "$TMP" \
    '{tool_name:"Bash", cwd:$c, tool_input:{command:$cmd}}'; }

  SMALL=$(printf 'x\ny\n')
  BIG=$(seq 1 31 | tr '\n' '@' | tr '@' '\n')

  echo "Edit / Write route:"
  check "+3 to corpus stays under the threshold" silent "$(edit "$SK" "$SMALL" "$(printf 'x\ny\nz\nw\nv\n')")"
  check "+29 to corpus warns"                    warn   "$(edit "$SK" "$SMALL" "$BIG")" "adds 29 lines"
  check "+29 outside the corpus is ignored"      silent "$(edit "$TMP/README.md" "$SMALL" "$BIG")"
  # Regression: the file does not exist at PreToolUse time, and the old code
  # emitted a shell redirect error to stderr while still computing the right
  # number. Counting is newline-based, so 31 lines reads as 31, not 32.
  check "Write of a new file counts from zero"   warn   "$(write "$CDIR/new.md" "$BIG")" "adds 30 lines"

  echo "Bash route:"
  check "grep is a read"                         silent "$(bash_p "grep -n q $SK")"
  check "cd && grep is still a read"             silent "$(bash_p "cd /tmp && grep -n q $SK")"
  # Regression: `2>/dev/null` used to satisfy the redirect gate, so a plain rm
  # naming a corpus path was reported as corpus growth.
  check "rm with 2>/dev/null is not a write"     silent "$(bash_p "rm $SK 2>/dev/null")"
  check "redirect to a non-corpus target"        silent "$(bash_p "cat $SK > /tmp/out.txt 2>/dev/null")"

  # Growth has to exist before the cumulative branch can report any.
  seq 1 40 >> "$SK"
  check "sed -i after real growth warns"         warn   "$(bash_p "sed -i '' s/a/b/ $SK")" "+40 lines"
  check "cd && sed -i warns the same"            warn   "$(bash_p "cd $TMP && sed -i '' s/a/b/ $SK")" "+40 lines"
  check "heredoc redirect to corpus warns"       warn   "$(bash_p "cat > $SK <<EOF
hi
EOF")" "+40 lines"
  check "untracked corpus .md counts too"        warn   "$(printf 'q\n' > "$CDIR/extra.md"; bash_p "sed -i '' s/a/b/ $SK")" "+41 lines"
  check "write outside the corpus is ignored"    silent "$(bash_p "sed -i '' s/a/b/ $TMP/README.md")"

  printf '\n%s passed, %s failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ] || exit 1
  exit 0
fi

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
        (((.tool_input.new_string // "") | split("\n") | length) - 1)
        - (((.tool_input.old_string // "") | split("\n") | length) - 1)')
    else
      # `split("\n") | length - 1` is the newline count, which is what wc -l
      # reports. Without the -1 the Write branch reads one line higher than the
      # Bash branch's corpus total for the very same file.
      NEW=$(printf '%s' "$INPUT" | jq -r '((.tool_input.content // "") | split("\n") | length) - 1')
      # PreToolUse runs before the file exists, and `< "$FILE"` fails in the
      # shell rather than in wc, so wc's own 2>/dev/null does not suppress it.
      OLD=0
      [ -f "$FILE" ] && OLD=$(wc -l < "$FILE" | tr -d ' ')
      ADDED=$((NEW - OLD))
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
    # An in-place editor, or a redirect whose TARGET is a corpus file. Matching
    # any redirect at all made `2>/dev/null` count as a write, which fired the
    # guard on a plain `rm` that happened to name a corpus path.
    WRITE_RE='sed[[:space:]]+-i|tee[[:space:]]|(python3?|perl|ruby)[[:space:]]|cp[[:space:]]|mv[[:space:]]|truncate[[:space:]]|<<'
    REDIR_RE=">>?[[:space:]]*[^ &|]*${CORPUS_RE}"
    printf '%s' "$CMD" | grep -qE "$WRITE_RE|$REDIR_RE" || exit 0

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
