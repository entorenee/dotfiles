#!/usr/bin/env bash
#
# Beads trial metrics: one snapshot per machine per window.
#
#   bash beads-trial.sh [--since YYYY-MM-DD] [--until YYYY-MM-DD]
#   bash beads-trial.sh --selftest
#
# Writes $TRIAL/snapshots/<host>-<until>.json and prints its path. Both dates
# are inclusive UTC days, matched against each session's first timestamp;
# --until defaults to today, --since to 28 days before --until.
#
# Arms come from $TRIAL/arms.tsv (repo<TAB>branch<TAB>arm<TAB>date), never from
# the transcripts, so a session cannot vote on its own arm. A row applies from
# its date onward. In a repo with any applicable row, a branch without its own
# row is `control` — the same call the prime hook makes, since an unlisted
# branch is never primed. A repo with no applicable row is `unarmed`; that is
# every repo in a pre-go-live window.
#
# Known blind spot: a ledger or memory file edited through Bash (sed, heredoc)
# is not a state edit here. Only Edit/Write/MultiEdit calls are counted.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
JQ_EXTRACT="$HERE/beads-trial.jq"

MODE=run
SINCE=""
UNTIL=""
while [ $# -gt 0 ]; do
  case "$1" in
  --selftest) MODE=selftest ;;
  --since)
    SINCE="${2:?--since needs YYYY-MM-DD}"
    shift
    ;;
  --until)
    UNTIL="${2:?--until needs YYYY-MM-DD}"
    shift
    ;;
  *)
    echo "beads-trial.sh: unknown argument '$1'" >&2
    exit 2
    ;;
  esac
  shift
done

TRANSCRIPTS="${SKILL_TRANSCRIPT_DIR:-$HOME/.claude/projects}"
CONFIG_DIR="${SKILL_CONFIG_DIR:-$HOME/dotfiles/modules/home/claude/config}"

# --------------------------------------------------------------------------
# Repo resolution. A transcript records the cwd, not the repo, and most
# monorepo worktrees are gone by the time anyone measures — `wt remove` is the
# end of every branch. So walk up to the nearest directory that still exists
# as a git checkout, and for a vanished worktree `<primary>.<branch>` try its
# `<primary>` sibling, which shares the branch refs.
#
# Emits cwd<TAB>repo<TAB>checkout; checkout is empty when nothing resolved, in
# which case repo is the cwd's basename and commit counts are skipped.
# --------------------------------------------------------------------------
repo_of_checkout() { # $1 = checkout top
  local url
  url=$(git -C "$1" remote get-url origin 2>/dev/null) || url="$1"
  basename -s .git "$url"
}

resolve_repo() { # $1 = cwd
  local p="$1" top base stem
  while [ -n "$p" ] && [ "$p" != "/" ] && [ "$p" != "." ]; do
    if [ -d "$p" ] && top=$(git -C "$p" rev-parse --show-toplevel 2>/dev/null); then
      printf '%s\t%s\t%s\n' "$1" "$(repo_of_checkout "$top")" "$top"
      return
    fi
    base=$(basename "$p")
    stem="${base%%.*}"
    if [ -n "$stem" ] && [ "$stem" != "$base" ] && [ -d "$(dirname "$p")/$stem" ] &&
      top=$(git -C "$(dirname "$p")/$stem" rev-parse --show-toplevel 2>/dev/null); then
      printf '%s\t%s\t%s\n' "$1" "$(repo_of_checkout "$top")" "$top"
      return
    fi
    p=$(dirname "$p")
  done
  printf '%s\t%s\t\n' "$1" "$(basename "$1")"
}

# --------------------------------------------------------------------------
# Commits on a branch whose message names an issue created in the user's own
# transcripts. Own IDs only: the monorepo database is shared, and a teammate's
# issue ID in a commit says nothing about this trial.
# --------------------------------------------------------------------------
count_commits() { # $1 = checkout, $2 = branch, $3 = newline-separated IDs
  local dir="$1" br="$2" ids="$3" ref def range
  [ -n "$dir" ] && [ -n "$ids" ] || {
    echo 0
    return
  }
  if git -C "$dir" rev-parse -q --verify "refs/heads/$br" >/dev/null; then
    ref="refs/heads/$br"
  elif git -C "$dir" rev-parse -q --verify "refs/remotes/origin/$br" >/dev/null; then
    ref="refs/remotes/origin/$br"
  else
    echo 0
    return
  fi
  def=$(git -C "$dir" symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null)
  # The default branch has no fork point to subtract, so it is bounded by the
  # window instead; a feature branch is everything it has that the default lacks.
  if [ -z "$def" ] || [ "refs/remotes/origin/$br" = "$def" ]; then
    range=("$ref" --since="$SINCE 00:00:00 +0000" --until="$UNTIL 23:59:59 +0000")
  else
    range=("$ref" "^$def")
  fi
  git -C "$dir" log --format='%B%x1e' "${range[@]}" 2>/dev/null |
    IDS="$ids" awk 'BEGIN { RS = "\036"; n = split(ENVIRON["IDS"], id, "\n") }
      { for (i = 1; i <= n; i++) if (id[i] != "" && index($0, id[i])) { c++; break } }
      END { print c + 0 }'
}

# --------------------------------------------------------------------------
# One snapshot. $1 = output path, $2 = "harness" to measure the skill system,
# anything else to skip it (the selftest has no skill system to measure).
# --------------------------------------------------------------------------
snapshot() {
  local out="$1" harness="$2" W f
  W=$(mktemp -d "${TMPDIR:-/tmp}/beads-trial.XXXXXX")

  # mtime is a cheap superset: a session that started in the window was
  # written to on or after its first day. The exact cut happens below.
  : >"$W/sessions.jsonl"
  while IFS= read -r -d '' f; do
    jq -c -sR -f "$JQ_EXTRACT" --arg art "$ART_ROOT" --arg file "$f" "$f" \
      >>"$W/sessions.jsonl" 2>>"$W/errors.txt" ||
      printf '%s\n' "$f" >>"$W/unreadable.txt"
  done < <(find "$TRANSCRIPTS" -type f -name '*.jsonl' ! -name 'agent-*' \
    ! -path '*/subagents/*' -newermt "$SINCE" -print0 2>/dev/null)

  jq -c --arg since "$SINCE" --arg until "$UNTIL" '
    select(.start != null
      and .start >= ($since + "T00:00:00Z" | fromdateiso8601)
      and .start < (($until + "T00:00:00Z" | fromdateiso8601) + 86400))
  ' "$W/sessions.jsonl" >"$W/window.jsonl"

  jq -r 'select(.cwd != null) | .cwd' "$W/window.jsonl" | sort -u |
    while IFS= read -r c; do resolve_repo "$c"; done >"$W/repos.tsv"

  # Branch pairs and own IDs per repo, so commits are counted once per branch.
  jq -rn --rawfile repos "$W/repos.tsv" '
    ($repos | split("\n") | map(select(length > 0) | split("\t")
      | {key: .[0], value: {repo: .[1], dir: .[2]}}) | from_entries) as $R
    | [inputs | select(.branch != null and .cwd != null) | . + $R[.cwd]] as $s
    | ($s | group_by(.repo) | map({key: .[0].repo, value: ([.[].created_ids[]] | unique)})
       | from_entries) as $ids
    | $s | map({repo, dir, branch}) | unique[]
    | [.repo, .dir, .branch, ($ids[.repo] | join("\u001f"))] | @tsv
  ' "$W/window.jsonl" >"$W/pairs.tsv"

  : >"$W/commits.tsv"
  while IFS=$'\t' read -r repo dir br ids; do
    printf '%s\t%s\t%s\n' "$repo" "$br" \
      "$(count_commits "$dir" "$br" "$(printf '%s' "$ids" | tr '\037' '\n')")" >>"$W/commits.tsv"
  done <"$W/pairs.tsv"

  local lines=null units=null
  if [ "$harness" = harness ]; then
    lines=$(find "$CONFIG_DIR/skills" "$CONFIG_DIR/commands" -type f -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
    units=$(bash "$HERE/inventory.sh" --json 2>/dev/null | jq '.units | length' 2>/dev/null) || units=null
    [ -n "$units" ] || units=null
  fi

  local arms_file="$TRIAL/arms.tsv"
  [ -f "$arms_file" ] || arms_file=/dev/null

  jq -n \
    --arg host "$HOST" --arg since "$SINCE" --arg until "$UNTIL" \
    --rawfile arms "$arms_file" --rawfile repos "$W/repos.tsv" \
    --rawfile commits "$W/commits.tsv" \
    --slurpfile sessions "$W/window.jsonl" \
    --argjson lines "$lines" --argjson units "$units" \
    --argjson unreadable "$([ -f "$W/unreadable.txt" ] && wc -l <"$W/unreadable.txt" | tr -d ' ' || echo 0)" '
    def tsv: split("\n") | map(select(length > 0 and (startswith("#") | not)) | split("\t"));

    ($repos | tsv | map({key: .[0], value: {repo: .[1], dir: .[2]}}) | from_entries) as $R
    | ($commits | tsv | map({key: (.[0] + "\t" + .[1]), value: (.[2] | tonumber)}) | from_entries) as $C
    | ($arms | tsv | map(select(.[0] != "repo"))
        | map({repo: .[0], branch: .[1], arm: .[2], date: .[3]})) as $rows

    | def armof:
        (.start | strftime("%Y-%m-%d")) as $d
        | . as $s
        | [ $rows[] | select(.repo == $s.repo and .date <= $d) ] as $live
        | if ($live | length) == 0 then "unarmed"
          else ([ $live[] | select(.branch == $s.branch) ] | sort_by(.date) | last)
               as $own
               | if $own == null then "control" else $own.arm end
          end;

      def armstats($repo):
        { branches: (map(.branch) | unique | length),
          sessions: length,
          state_edits: (map(.state_edits) | add),
          handoff_runs: (map(.handoff_runs) | add),
          reflect_runs: (map(.reflect_runs) | add),
          corrections: (map(.corrections) | add),
          prepr_runs: (map(.prepr_runs) | add),
          prepr_corrections: (map(.prepr_corrections) | add),
          # Per branch, across all its sessions: an own issue created before
          # the first edit to product code.
          issue_before_first_edit: (
            group_by(.branch)
            | map( ([ .[].first_create_ts | numbers ] | min) as $c
                   | ([ .[].first_product_edit_ts | numbers ] | min) as $e
                   | select($c != null and ($e == null or $c < $e)) )
            | length),
          commits_with_issue_id: (
            map(.branch) | unique | map($C[$repo + "\t" + .] // 0) | add // 0) };

    { host: $host,
        window: {since: $since, until: $until},
        unreadable_transcripts: $unreadable,
        repos: (
          [ $sessions[] | . + ($R[.cwd] // {repo: "(no cwd)", dir: ""}) ]
          | group_by(.repo)
          | map( .[0].repo as $repo
                 | { key: $repo,
                     value: {
                       arms: ( map(select(.branch != null) | . + {arm: armof})
                               | group_by(.arm)
                               | map({key: .[0].arm, value: armstats($repo)})
                               | from_entries ),
                       unattributed_sessions: (map(select(.branch == null)) | length) } } )
          | from_entries ),
        harness: {skill_lines: $lines, units: $units} }
  ' >"$out"

  local rc=$?
  rm -r "$W"
  return $rc
}

# --------------------------------------------------------------------------
# Selftest: synthetic transcripts with known answers.
# --------------------------------------------------------------------------
if [ "$MODE" = selftest ]; then
  T=$(mktemp -d "${TMPDIR:-/tmp}/beads-trial-selftest.XXXXXX")
  mkdir -p "$T/projects/-fx" "$T/trial"
  TRANSCRIPTS="$T/projects"
  TRIAL="$T/trial"
  ART_ROOT="/art"
  HOST=selftest
  SINCE=2026-11-01
  UNTIL=2026-11-30

  printf 'repo\tbranch\tarm\tdate\n' >"$TRIAL/arms.tsv"
  printf 'fx\tfeat/beads\tbeads\t2026-11-01\n' >>"$TRIAL/arms.tsv"
  printf 'fx\tfeat/control\tcontrol\t2026-11-01\n' >>"$TRIAL/arms.tsv"
  printf 'fx\tfeat/foreign\tbeads\t2026-11-01\n' >>"$TRIAL/arms.tsv"

  # Record builders. $BR is the session's gitBranch ("" omits the field);
  # every record gets the next minute so ordering is explicit. N is bumped in
  # each builder, never inside base(): base runs in a $( ) subshell, where an
  # increment is lost and every record would share one timestamp.
  CWD=/nonexistent/fx
  N=0
  base() { jq -nc --arg ts "$(printf '%s:%02d:00.000Z' "$DAY" "$N")" --arg br "$BR" \
    --arg cwd "$CWD" --arg sid "$SID" \
    '{timestamp: $ts, cwd: $cwd, sessionId: $sid} + (if $br == "" then {} else {gitBranch: $br} end)'; }
  human() {
    N=$((N + 1))
    jq -c --arg t "$1" '. + {type: "user", message: {role: "user", content: $t}}' <<<"$(base)"
  }
  tool() { # $1 name, $2 input json, $3 id
    N=$((N + 1))
    jq -c --arg n "$1" --argjson in "$2" --arg id "$3" \
      '. + {type: "assistant", message: {role: "assistant", content: [{type: "tool_use", id: $id, name: $n, input: $in}]}}' <<<"$(base)"
  }
  result() { # $1 id, $2 text
    N=$((N + 1))
    jq -c --arg id "$1" --arg t "$2" \
      '. + {type: "user", message: {role: "user", content: [{type: "tool_result", tool_use_id: $id, content: $t}]}}' <<<"$(base)"
  }
  edit() { tool Edit "$(jq -nc --arg p "$1" '{file_path: $p}')" "e$N"; }
  skill() { tool Skill "$(jq -nc --arg s "$1" '{skill: $s}')" "s$N"; }

  # beads-arm: own issue created before the first product edit.
  SID=beads DAY=2026-11-10T10 BR=feat/beads N=0
  {
    human "start the work"
    tool Bash '{"command":"bd create \"thing\" -t task"}' b1
    result b1 "✓ Created issue: fx-abc — thing"
    edit /nonexistent/fx/src/a.ts
    edit /art/fx/plans/2026-11-10-thing-progress.md
    edit "$HOME/.claude/projects/-fx/memory/m.md"
    human "no, that's wrong"
    human "looks good"
  } >"$T/projects/-fx/beads.jsonl"

  # control-arm: pre-pr's own hygiene call and a built-in command keep the
  # window open; the next unrelated skill closes it.
  SID=control DAY=2026-11-11T10 BR=feat/control N=0
  {
    human "begin"
    edit /art/fx/plans/2026-11-11-x-progress.md
    edit /art/fx/plans/2026-11-11-x.md
    edit "$HOME/.claude/projects/-fx/memory/n.md"
    edit /art/fx/plans/other-progress.md
    human "that's wrong"
    human "actually use the other one"
    skill pre-pr
    skill fw-code-hygiene
    human "<command-name>/compact</command-name>"
    human "don't do that"
    human "revert it"
    skill code-review
    human "stop there"
    human "great"
  } >"$T/projects/-fx/control.jsonl"

  # Out of window: must count nowhere.
  SID=old DAY=2026-08-01T10 BR=feat/control N=0
  {
    human "that's wrong"
    edit /art/fx/plans/old-progress.md
  } >"$T/projects/-fx/old.jsonl"

  # no-branch and detached HEAD: unattributed, never in an arm.
  SID=nobranch DAY=2026-11-12T10 BR="" N=0
  {
    human "that's wrong"
    edit /art/fx/plans/nb-progress.md
  } >"$T/projects/-fx/nobranch.jsonl"
  SID=detached DAY=2026-11-12T11 BR=HEAD N=0
  {
    human "that's wrong"
    edit /art/fx/plans/dh-progress.md
  } >"$T/projects/-fx/detached.jsonl"

  # foreign-issue: reads a teammate's issue, and a decoy whose command only
  # mentions bd create. Neither is an own issue.
  SID=foreign DAY=2026-11-13T10 BR=feat/foreign N=0
  {
    human "look at fx-zzz"
    tool Bash '{"command":"bd show fx-zzz"}' f1
    result f1 "fx-zzz · teammate issue"
    tool Bash '{"command":"rtk rewrite \"bd create x\""}' f2
    result f2 "Created issue: fx-dec"
    edit /nonexistent/fx/src/b.ts
  } >"$T/projects/-fx/foreign.jsonl"

  # Gated repo, unlisted branch → control. Ungated repo → unarmed.
  SID=unlisted DAY=2026-11-14T10 BR=feat/unlisted N=0
  { human "hello"; } >"$T/projects/-fx/unlisted.jsonl"
  SID=other DAY=2026-11-14T11 BR=main CWD=/nonexistent/other N=0
  { human "that's wrong"; } >"$T/projects/-fx/other.jsonl"

  # Subagent transcripts carry no human and must be skipped wholesale.
  mkdir -p "$T/projects/-fx/control/subagents"
  SID=control DAY=2026-11-11T12 BR=feat/control CWD=/nonexistent/fx N=0
  { human "that's wrong"; } >"$T/projects/-fx/control/subagents/agent-x.jsonl"

  OUT="$T/out.json"
  snapshot "$OUT" none || {
    echo "FAIL  snapshot exited non-zero"
    exit 1
  }

  pass=0
  fail=0
  check() { # $1 label, $2 jq path, $3 expected (compact JSON)
    local got
    got=$(jq -c "$2" "$OUT")
    if [ "$got" = "$3" ]; then
      pass=$((pass + 1))
      printf '  ok    %s\n' "$1"
    else
      fail=$((fail + 1))
      printf '  FAIL  %s — expected %s, got %s\n' "$1" "$3" "$got"
    fi
  }
  B='.repos.fx.arms.beads'
  C='.repos.fx.arms.control'
  check "beads: state edits (progress + memory, not product)" "$B.state_edits" 2
  check "beads: corrections" "$B.corrections" 1
  check "beads: own issue before first edit; foreign + decoy add 0" "$B.issue_before_first_edit" 1
  check "beads: two branches listed" "$B.branches" 2
  check "control: state edits" "$C.state_edits" 4
  check "control: corrections (window excludes the August session)" "$C.corrections" 5
  check "control: pre-pr runs" "$C.prepr_runs" 1
  check "control: pre-pr window survives hygiene + /compact, closes at next skill" "$C.prepr_corrections" 2
  check "control: unlisted branch in gated repo joins control" "$C.branches" 2
  check "no-branch + detached HEAD are unattributed" ".repos.fx.unattributed_sessions" 2
  check "ungated repo is unarmed" '.repos.other.arms | keys' '["unarmed"]'
  check "subagent transcript skipped" "$C.sessions" 2
  check "no unreadable transcripts" ".unreadable_transcripts" 0

  rm -r "$T"
  printf '%d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]
  exit
fi

# --------------------------------------------------------------------------
# Real run.
# --------------------------------------------------------------------------
TRIAL="${BEADS_TRIAL_DIR:-${MY_AGENT_ARTIFACTS_ROOT:?unset — run 'make rebuild', then start a new session}/dotfiles/beads-trial}"
ART_ROOT="$MY_AGENT_ARTIFACTS_ROOT"
HOST=$(hostname -s)

day() { # $1 = YYYY-MM-DD, $2 = day offset
  jq -rn --arg d "$1" --argjson o "$2" '($d + "T00:00:00Z" | fromdateiso8601) + $o * 86400 | strftime("%Y-%m-%d")'
}
[ -n "$UNTIL" ] || UNTIL=$(date -u +%Y-%m-%d)
[ -n "$SINCE" ] || SINCE=$(day "$UNTIL" -28)

mkdir -p "$TRIAL/snapshots"
OUT="$TRIAL/snapshots/$HOST-$UNTIL.json"
snapshot "$OUT" harness || exit 1
printf '%s\n' "$OUT"
