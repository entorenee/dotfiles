#!/usr/bin/env bash
#
# Cross-arm usage inventory for every local skill and slash command.
#
#   bash inventory.sh            human table
#   bash inventory.sh --json     one JSON record per unit
#
# Answers one question per unit: is there evidence it ran, and from which arm.
#
# Four arms, because no single one sees everything:
#
#   direct    — a Skill tool call or a slash command in the transcripts.
#               Blind to a skill executed inline by another skill.
#   artifact  — a report under $ARTIFACTS/<repo>/<area>/. Sees composed runs the
#               direct arm misses, but only for units that write reports, and it
#               attributes by convention rather than by record.
#   composed  — a caller with direct runs, via the verified composition graph.
#               Establishes reachability, never that a specific run happened.
#   testimony — testimony.txt: what the user reported when a machine arm was
#               wrong. The only arm that can see an inline run leaving no trace.
#
# A unit with no evidence in any arm is `no-evidence`, which is NOT the same as
# unused. Reporting it as unused is the exact mistake this script exists to stop.
#
# --json exists so /system-review can decide what is due without re-deriving
# dates and git history by hand. It did, once, and that is a weekly job nobody
# would keep doing.

set -uo pipefail

MODE=table
case "${1:-}" in
  --json) MODE=json ;;
  --selftest) MODE=selftest ;;
esac

CONFIG_DIR="${SKILL_CONFIG_DIR:-$HOME/dotfiles/modules/home/claude/config}"
TRANSCRIPTS="${SKILL_TRANSCRIPT_DIR:-$HOME/.claude/projects}"
# Guarded, not defaulted: a wrong root finds nothing and reports every
# report-writing skill as unused.
ART_ROOT="${SKILL_ARTIFACT_ROOT:-${MY_CLAUDE_ARTIFACTS_ROOT:?unset — run 'make rebuild', then start a new session}}"
# Checkout first: at runtime $0 is a /nix/store symlink, so a correction
# appended to testimony.txt stays inert there until the next rebuild.
TESTIMONY="$CONFIG_DIR/skills/skill-reviewer/testimony.txt"
[ -f "$TESTIMONY" ] || TESTIMONY="$(dirname "$0")/testimony.txt"
[ -f "$TESTIMONY" ] || TESTIMONY=/dev/null

WORK="${TMPDIR:-/tmp}/skill-inventory"
mkdir -p "$WORK"

# --------------------------------------------------------------------------
# Ledger arm: when each unit was last *reviewed*.
#
# The staleness half of the threshold — "45 days since the last row" — asks
# about review history, which no other arm can answer: the direct arm knows
# when a unit last ran, never when it was last examined.
#
# ONE canonical path, ABOVE the per-repo layout. The ledger measures the skill
# system, which is machine-global — same units, same thresholds, whatever repo a
# session started in. Keying it by repo partitioned on cwd, which is not a stable
# identifier, and the read side then took `find … | head -1`: with two repo keys
# one ledger was silently discarded. Measured 2026-08-27 on a two-key fixture, a
# unit reviewed 2026-08-26 vanished outright and another reported a date 13 days
# stale. Depth 3 is still scanned, but only to REPORT strays — never to read one.
#
# The date is anchored to the token after the em dash rather than found by
# scanning the line. Scanning fell through a malformed date to whatever else
# looked date-shaped — and the row convention allows a second date in a
# parenthetical (`## pre-pr — 2026-08-12 (row renamed 2026-08-17)`), so the
# fall-through landed on a real but WRONG field. It read newer, which suppresses
# the staleness arm, so the failure hid overdue units rather than inventing them.
#
# Unit keys are lowercase-kebab, which is what drops the prose sections
# (`## Provenance …`, `## Instrument change …`) without needing a filter.
#
# Status is emitted rather than inferred from an empty result. `absent`, `empty`
# and `unparsed` all produced a column of dashes before, and only the first two
# mean "no ledger" — the third means one exists and did not parse.
# --------------------------------------------------------------------------
ledger_scan() { # $1 = artifact root, $2 = output tsv; echoes the status
  local root="$1" out="$2"
  local canonical="$root/skill-reviewer/LEDGER.md"
  local n_stray rows
  : > "$out"

  n_stray=$(find "$root" -mindepth 3 -maxdepth 3 -path '*/skill-reviewer/LEDGER.md' \
            2>/dev/null | wc -l | tr -d ' ')

  if [ -f "$canonical" ]; then
    awk '
      # $1 "##", $2 unit, $3 em dash, $4 date. Anchored: a row whose date is not
      # in position 4 is not parsed at all, rather than parsed from elsewhere.
      $1 == "##" && $2 ~ /^[a-z0-9-]+$/ && $3 == "—" &&
      $4 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ {
        d = substr($4, 1, 10);
        if (d > seen[$2]) seen[$2] = d;
      }
      END { for (u in seen) printf "%s\t%s\n", u, seen[u] }
    ' "$canonical" > "$out"
  fi

  rows=$(wc -l < "$out" | tr -d ' ')

  # A stray outranks the canonical result: rows exist somewhere they will not be
  # read from, and that is the finding regardless of how well the canonical one
  # parsed. It is also the migration signal — a ledger still under a repo key
  # reports split:1 with nothing canonical yet.
  if [ "$n_stray" -gt 0 ]; then echo "split:$n_stray"
  elif [ ! -f "$canonical" ]; then echo "absent"
  elif [ ! -s "$canonical" ]; then echo "empty"
  elif [ "$rows" -eq 0 ]; then echo "unparsed"
  else echo "parsed:$rows"
  fi
}

# Newest review trailer for one unit's file, on any machine. See the Review arm
# below for why this reads the raw body rather than `%(trailers)`.
# Split in two so the parsing half is testable without creating a commit. Commits
# here are signed from a hardware key and cannot be scripted, so a selftest that
# builds a scratch repo does not run — it silently produces zero commits and every
# case reads EMPTY, which looks like a parser bug and is not one.
#
# The fixtures feed review_trailer_parse the exact byte shape `git log
# --format='%x1e%ad%x1f%B'` emits, verified against a real commit.
review_trailer_parse() { # stdin = that stream; echoes "date<TAB>host<TAB>runs"
  # LC_ALL=C: tr is locale-sensitive and errors with "Illegal byte sequence" on
  # input it cannot decode as the locale's charset. Commit bodies carry em dashes
  # and whatever else a human typed, and this arm has to give the same answer on
  # every machine, so the separators are treated as bytes rather than characters.
  LC_ALL=C tr '\n' ' ' | LC_ALL=C tr '\036' '\n' \
    | LC_ALL=C awk -F'\037' '
        NF > 1 && $2 ~ /Reviewed-on:[ \t]*[^ \t]/ {
          host = $2; sub(/.*Reviewed-on:[ \t]*/, "", host); sub(/[ \t].*/, "", host);
          runs = "-";
          if (match($2, /Runs-analyzed:[ \t]*[0-9]+/)) {
            runs = substr($2, RSTART, RLENGTH); sub(/[^0-9]*/, "", runs);
          }
          gsub(/^[ \t]+|[ \t]+$/, "", $1);
          printf "%s\t%s\t%s\n", $1, host, runs; exit
        }'
}

review_trailer_scan() { # $1 = git dir, $2 = path within it
  git -C "$1" log --follow --date=short --grep='Reviewed-on:' \
      --format='%x1e%ad%x1f%B' -- "$2" 2>/dev/null | review_trailer_parse
}

if [ "$MODE" = selftest ]; then
  T="$WORK/selftest"; rm -rf "$T"; mkdir -p "$T"
  pass=0; fail=0
  check() { # $1 = label, $2 = expected status, $3 = root, $4 = expected "unit=date,…"
    local got extra=""
    got=$(ledger_scan "$3" "$T/out.tsv")
    if [ -n "${4:-}" ]; then
      extra=$(sort "$T/out.tsv" | awk -F'\t' '{printf "%s=%s,", $1, $2}')
      [ "$extra" = "$4" ] || got="$got rows=$extra"
    fi
    if [ "$got" = "$2" ]; then pass=$((pass+1)); printf '  ok    %s\n' "$1"
    else fail=$((fail+1)); printf '  FAIL  %s — expected "%s", got "%s"\n' "$1" "$2" "$got"; fi
  }

  mkdir -p "$T/absent"
  check "no ledger anywhere reads as absent" "absent" "$T/absent"

  mkdir -p "$T/empty/skill-reviewer"; : > "$T/empty/skill-reviewer/LEDGER.md"
  check "a zero-byte ledger is empty, not absent" "empty" "$T/empty"

  mkdir -p "$T/good/skill-reviewer"
  printf '## investigate — 2026-07-02\n\ntext\n\n## pre-pr — 2026-08-12 (row renamed 2026-08-17)\n\n## Provenance — state the matcher\n' \
    > "$T/good/skill-reviewer/LEDGER.md"
  check "well-formed rows parse, parenthetical date ignored" "parsed:2" "$T/good" \
    "investigate=2026-07-02,pre-pr=2026-08-12,"

  mkdir -p "$T/baddate/skill-reviewer"
  printf '## investigate — 07/02/2026\n\n## pre-pr — 08/12/2026 (row renamed 2026-08-17)\n' \
    > "$T/baddate/skill-reviewer/LEDGER.md"
  check "off-convention dates fail loudly, never fall through" "unparsed" "$T/baddate"

  mkdir -p "$T/reheaded/skill-reviewer"
  printf '### investigate (2026-07-02)\n\n### pre-pr (2026-08-12)\n' \
    > "$T/reheaded/skill-reviewer/LEDGER.md"
  check "reorganized headers are unparsed, not absent" "unparsed" "$T/reheaded"

  mkdir -p "$T/split/dotfiles/skill-reviewer" "$T/split/other-repo/skill-reviewer"
  printf '## investigate — 2026-08-12\n' > "$T/split/dotfiles/skill-reviewer/LEDGER.md"
  printf '## fw-investigate — 2026-08-26\n' > "$T/split/other-repo/skill-reviewer/LEDGER.md"
  check "ledgers under repo keys report split, never head -1" "split:2" "$T/split"

  # Review arm. Fixtures are the byte shape `git log --format='%x1e%ad%x1f%B'`
  # emits — RS \x1e, then the date, then US \x1f, then the whole message.
  tcheck() { # $1 = label, $2 = expected "date host runs" or EMPTY, $3 = message
    local got
    got=$(printf '\036%s\037%b' "2026-08-19" "$3" | review_trailer_parse \
          | awk -F'\t' '{printf "%s %s %s", $1, $2, $3}')
    [ -z "$got" ] && got="EMPTY"
    if [ "$got" = "$2" ]; then pass=$((pass+1)); printf '  ok    %s\n' "$1"
    else fail=$((fail+1)); printf '  FAIL  %s — expected "%s", got "%s"\n' "$1" "$2" "$got"; fi
  }

  tcheck "a commit with no trailer yields nothing, never a date" "EMPTY" \
    'chore: no trailer here\n'

  tcheck "a clean trailer block parses" "2026-08-19 host-a 7" \
    'refactor: edits\n\nReviewed-on: host-a\nRuns-analyzed: 7\n'

  # The two shapes that yield ZERO trailers under git's own parser. Step 5 tells
  # the user to paste `Expected to fail: …` into this very commit, so both are
  # the expected case, not the exotic one.
  tcheck "a spaced key beside it does not suppress the match" "2026-08-19 host-b 12" \
    'refactor: edits\n\nExpected to fail: the description trigger\nReviewed-on: host-b\nRuns-analyzed: 12\n'

  tcheck "placement above a later paragraph still parses" "2026-08-19 host-c 3" \
    'refactor: edits\n\nReviewed-on: host-c\nRuns-analyzed: 3\n\nExpected to fail: wraps\nonto two lines\n'

  tcheck "Runs-analyzed absent degrades to -, never to a guess" "2026-08-19 host-d -" \
    'refactor: edits\n\nReviewed-on: host-d\n'

  # Built from two printfs, not one string: in `%b`, `\036` followed by a digit
  # is read as a longer octal escape (`\0362` is one byte, 0xF2) and silently
  # corrupts the record separator.
  got=$( { printf '\036%s\037%b' "2026-08-19" 'newer\n\nReviewed-on: host-new\nRuns-analyzed: 2\n'
           printf '\036%s\037%b' "2026-01-01" 'older\n\nReviewed-on: host-old\nRuns-analyzed: 9\n'
         } | review_trailer_parse | awk -F'\t' '{printf "%s %s %s", $1, $2, $3}')
  if [ "$got" = "2026-08-19 host-new 2" ]; then
    pass=$((pass+1)); printf '  ok    newest commit wins when several carry the trailer\n'
  else
    fail=$((fail+1))
    printf '  FAIL  newest commit wins when several carry the trailer — got "%s"\n' "$got"
  fi

  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ] || exit 1
  exit 0
fi

# --------------------------------------------------------------------------
# Composition graph: "child parent" per line.
#
# Derive edges from invocation language, never by grepping for names: a name in
# a "NOT for this, use X" line is a disclaimer, not an edge.
# --------------------------------------------------------------------------
cat > "$WORK/composition.txt" <<'EOF'
evidence-analysis-core analytics-friction-analysis
evidence-analysis-core error-triage
evidence-analysis-core regression-analysis
evidence-analysis-core evidence-consolidation
analytics-friction-analysis evidence-consolidation
error-triage evidence-consolidation
regression-analysis evidence-consolidation
code-hygiene pre-pr
comment-review code-hygiene
domain-register feature-plan
domain-register investigate
permission-audit config-health
EOF

# --------------------------------------------------------------------------
# Units.
# --------------------------------------------------------------------------
{ ls -1 "$CONFIG_DIR/skills"; ls -1 "$CONFIG_DIR/commands" | sed 's/\.md$//'; } \
  | sed 's#/$##' | sort -u > "$WORK/units.txt"

# --------------------------------------------------------------------------
# Direct arm. Emits: unit, file, top|sub, YYYY-MM-DD
#
# Both patterns are pinned to the record shape a real invocation produces,
# because a session analysing skill usage writes the search strings into its own
# transcript and an unguarded grep counts the analysis as a run. A Skill call is
# a tool_use on an assistant turn; a slash command is string-valued content.
# Echoes of either arrive inside tool_result arrays.
#
# The top|sub column splits a real session from a subagent one. A sidechain
# record is a genuine use but not a run: no human is present, so folding it into
# the session count invents runs that were never gated. Classified per record on
# "isSidechain":true rather than by filename — an agent-*.jsonl name is a
# convention, the field is the fact.
# --------------------------------------------------------------------------
grep -rH '"type":"assistant"' "$TRANSCRIPTS" 2>/dev/null \
  | grep '"name":"Skill"' \
  | awk -F'.jsonl:' 'NF>1 {
      f=$1; m=$2;
      side = (m ~ /"isSidechain":[ ]*true/) ? "sub" : "top";
      d = "-"; if (match(m, /"timestamp":"[^"]+"/)) d = substr(m, RSTART+13, 10);
      while (match(m, /"skill":"[a-z0-9-]+"/)) {
        print substr(m, RSTART+9, RLENGTH-10) "\t" f "\t" side "\t" d;
        m = substr(m, RSTART+RLENGTH);
      }
    }' > "$WORK/direct.tsv"

grep -rH '"content":"<command-message>' "$TRANSCRIPTS" 2>/dev/null \
  | awk -F'.jsonl:' 'NF>1 {
      f=$1; m=$2;
      side = (m ~ /"isSidechain":[ ]*true/) ? "sub" : "top";
      d = "-"; if (match(m, /"timestamp":"[^"]+"/)) d = substr(m, RSTART+13, 10);
      while (match(m, /<command-name>\/[a-z0-9-]+<\/command-name>/)) {
        print substr(m, RSTART+15, RLENGTH-30) "\t" f "\t" side "\t" d;
        m = substr(m, RSTART+RLENGTH);
      }
    }' >> "$WORK/direct.tsv"

# One date per session, not per invocation: two invocations in one transcript are
# one run, and runs_since counts runs.
#
# The last column is the unit's session set as transcript ids, ",3,7,", so the
# row builder can ask whether one unit's runs all happened inside another's.
awk -F'\t' '
  { u=$1; seen[u]=1;
    if ($3 == "sub") { subinv[u]++; next }
    inv[u]++;
    if (!((u SUBSEP $2) in fseen)) {
      fseen[u,$2]=1; sess[u]++;
      if (!($2 in fid)) fid[$2] = ++nf;
      if (fl[u] == "") fl[u] = ",";
      fl[u] = fl[u] fid[$2] ",";
      dates[u] = dates[u] (dates[u]=="" ? "" : ",") $4;
      if ($4 > last[u]) last[u] = $4;
    }
  }
  END { for (u in seen)
          printf "%s\t%d\t%d\t%d\t%s\t%s\t%s\n", u, inv[u], sess[u], subinv[u],
                 (last[u]=="" ? "-" : last[u]), (dates[u]=="" ? "-" : dates[u]),
                 (fl[u]=="" ? "-" : fl[u]) }
' "$WORK/direct.tsv" > "$WORK/direct-tally.tsv"

# --------------------------------------------------------------------------
# Git arm: when each unit last actually changed.
#
# Eligibility counts runs since the commit that last changed the unit, so a
# skill edited yesterday is not due however often it ran before. Commits with a
# zero numstat (pure renames) are skipped — the tree has been moved wholesale
# several times. A path-only rewrite still shows as a content change and cannot
# be told from a tightening here; the sweep prints the commit subject so that
# call stays with the reader, where the skill's rules put it.
#
# `--numstat` is TAB-separated and the awk below must say so. Under the default
# whitespace FS a rename renders its path as `{old => new}/rest`, whose spaces
# split the line into 5 fields, so an `NF == 3` guard silently dropped every
# commit that renamed *and* edited a unit — and left `($1 + $2) > 0`, the guard
# that is actually supposed to skip pure renames, unreachable. Measured
# 2026-08-19 on this repo: six such commits across `config-health` and
# `permission-audit`, moving `permission-audit`'s last-changed date from
# 2026-07-28 to 2026-08-07. A too-old date inflates `runs_since`, so the effect
# was units reading as due earlier than they are.
# --------------------------------------------------------------------------
: > "$WORK/changed.tsv"
if git -C "$CONFIG_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  while read -r u; do
    [ -n "$u" ] || continue
    if   [ -f "$CONFIG_DIR/skills/$u/SKILL.md" ]; then p="skills/$u/SKILL.md"
    elif [ -f "$CONFIG_DIR/commands/$u.md" ];     then p="commands/$u.md"
    else continue; fi
    git -C "$CONFIG_DIR" log --follow --numstat --date=short \
        --format='C%ad %s' -- "$p" 2>/dev/null \
      | awk -F'\t' -v u="$u" '
          /^C/ { d = substr($0, 2, 10); s = substr($0, index($0, " ") + 1); next }
          NF == 3 && ($1 + $2) > 0 { printf "%s\t%s\t%s\n", u, d, s; exit }'
  done < "$WORK/units.txt" >> "$WORK/changed.tsv"
fi

# --------------------------------------------------------------------------
# Review arm: when each unit was last reviewed on ANY machine.
#
# A review's record rides the commit that carries its edits. That commit is in
# this repo, which already syncs, so the fact of a review needs no file of its
# own and cannot fragment across machines the way a stored record does. The
# ledger keeps the measurements; they describe one machine's transcript archive
# and are meaningless anywhere else.
#
# Read from the raw body, NOT `%(trailers)`. Git's trailer parser takes only the
# final paragraph and rejects the whole block if any line's key holds a space —
# and Step 5 has long told the user to paste `Expected to fail: …` into this same
# commit. Measured 2026-08-27 on git 2.54: a block mixing that line with
# `Reviewed-on:` parses as ZERO trailers, as does a clean trailer block with that
# line in a later paragraph. The failure is silent and total, so the tolerant
# match is the correct one here and `%(trailers)` must not be reintroduced.
#
# `git log` is newest-first, so the first match is the most recent review and the
# scan stops there. `--grep` pre-filters so the body walk stays cheap.
# --------------------------------------------------------------------------
: > "$WORK/reviewed-git.tsv"
if git -C "$CONFIG_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  while read -r u; do
    [ -n "$u" ] || continue
    if   [ -f "$CONFIG_DIR/skills/$u/SKILL.md" ]; then p="skills/$u/SKILL.md"
    elif [ -f "$CONFIG_DIR/commands/$u.md" ];     then p="commands/$u.md"
    else continue; fi
    r=$(review_trailer_scan "$CONFIG_DIR" "$p")
    [ -n "$r" ] && printf '%s\t%s\n' "$u" "$r"
  done < "$WORK/units.txt" >> "$WORK/reviewed-git.tsv"
fi

# Ledger arm — see ledger_scan() above for the path, parse and status rules.
#
# The ledger is machine-local and outside the repo, so a fresh machine
# legitimately has none. Every unit then reports last_reviewed null, the
# staleness arm cannot fire at all, and the run-count arm carries the cadence
# alone. That is a limitation to state, not one to paper over with a guess —
# and LEDGER_STATUS is what lets a reader tell it apart from a parse failure.
LEDGER_STATUS=$(ledger_scan "$ART_ROOT" "$WORK/reviewed.tsv")
LEDGER_STRAYS=$(find "$ART_ROOT" -mindepth 3 -maxdepth 3 \
                -path '*/skill-reviewer/LEDGER.md' 2>/dev/null)

# --------------------------------------------------------------------------
# Artifact arm.
#
# One root, laid out as <repo>/<area>/<file>, keyed on the git remote name so
# every worktree of a repo lands in the same place.
# --------------------------------------------------------------------------
find "$ART_ROOT" -mindepth 3 -maxdepth 3 -type f 2>/dev/null > "$WORK/artifact-files.txt"
ART_N=$(wc -l < "$WORK/artifact-files.txt" | tr -d ' ')
# `skill-reviewer` sits at this depth too, holding the ledger, but it is not a
# repo — counting it inflates the figure the header prints.
REPO_N=$(find "$ART_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name skill-reviewer \
         2>/dev/null | wc -l | tr -d ' ')

# <repo>/<area>/<file>, so the area for the owner map is the second-to-last
# component. No deduplication: with one root per remote there are no copies to
# collapse, and two repos that happen to name a report the same way really are
# two artifacts.
awk -F/ '{ print $(NF-1) "/" $NF }' "$WORK/artifact-files.txt" > "$WORK/artifact-keys.txt"

# area/filename -> skill, or a pipe-joined candidate set when the filename does
# not settle it. An ambiguous artifact is reported as a set and counted for
# nobody: guessing an owner is worse than an unattributed row.
#
# The third column separates a dated report from a working byproduct. One run
# emits a report and often several CSV/SQL files beside it, so counting files
# counts one run many times — analytics showed 3 artifacts for a single run.
awk -F/ '
  {
    area = $1; file = $2; low = tolower(file); owner = "";
    if      (area == "error-triage")  owner = "error-triage";
    else if (area == "analytics")     owner = "analytics-friction-analysis";
    else if (area == "regressions")   owner = "regression-analysis";
    else if (area == "consolidated")  owner = "evidence-consolidation";
    else if (area == "dead-code")     owner = "dead-code-survey";
    else if (area == "changelogs")    owner = "changelog-generation";
    else if (area == "config-health") owner = "config-health";
    # The ledger belongs to this reviewer, not to a run; counting it would have
    # the loop measuring itself. (No apostrophes: this awk program sits inside a
    # single-quoted shell string.)
    else if (area == "skill-reviewer") next;
    # feature-plan is the sole live owner of this area, having absorbed two
    # predecessors. Artifacts they produced are still on disk and are counted
    # here, so a usage total over `plans/` is not a clean before/after for the
    # consolidation -- it includes runs feature-plan did not make.
    else if (area == "plans")         owner = "feature-plan";
    else if (area == "reviews") {
      # Boundary-anchored on both sides. `^pre-pr-` alone missed every dated
      # report, since the dated-filename convention this awk enforces two lines
      # down puts the date first. A trailing `-` alone then still missed the
      # suffix form: `2026-08-18-ranked-employer-ui-pre-pr.md` ends the name
      # with the skill, so the match has to accept `.` as the right boundary
      # too. Both forms are live on disk, along with one undated `pre-pr-…`
      # that the leading `^` does catch.
      if      (low ~ /(^|-)pre-pr(-|\.)/)  owner = "pre-pr";
      else if (low ~ /review/)    owner = "pr-review";
      else owner = "pr-review|pre-pr";
    }
    else owner = "?unmapped-area";
    dated = (file ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-/) ? "dated" : "raw";
    print owner "\t" area "/" file "\t" dated;
  }' "$WORK/artifact-keys.txt" > "$WORK/artifact-owned.tsv"

grep -v '|' "$WORK/artifact-owned.tsv" | grep -v '^?' \
  | awk -F'\t' '{ n[$1]++; if ($3 == "dated") r[$1]++ }
                END { for (k in n) print k "\t" n[k] "\t" (r[k]+0) }' \
  > "$WORK/artifact-tally.tsv"

# --------------------------------------------------------------------------
# Canonical rows. Both output modes format this and nothing else.
# unit inv sess sub art_runs art_files last_run changed changed_subject
#      runs_since via verdict composed_by last_reviewed
#
# last_reviewed is appended rather than slotted in beside last_run so the
# positional readers below — the table's field list and the JSON index map —
# keep their existing offsets.
# --------------------------------------------------------------------------
awk -F'\t' '
  FILENAME==dtally { inv[$1]=$2; sess[$1]=$3; sub_[$1]=$4; last[$1]=$5; dts[$1]=$6;
                     fl[$1]=$7; next }
  FILENAME==atally { artf[$1]=$2; artr[$1]=$3; next }
  FILENAME==chg    { chgd[$1]=$2; chgs[$1]=$3; next }
  FILENAME==rev    { rvd[$1]=$2; next }
  FILENAME==revgit { rgd[$1]=$2; rgh[$1]=$3; rgn[$1]=$4; next }
  FILENAME==comp   { split($0, e, " "); parent[e[1]] = parent[e[1]] " " e[2]; next }
  FILENAME==testim { if ($0 ~ /^#/ || $0 == "") next;
                     split($0, t, " "); said[t[1]]=t[2]; note[t[1]]=t[3]; next }
  {
    unit = $1;
    # Transitive: a caller counts if it has direct runs, or if something that
    # calls *it* does.
    via = ""; seen = ""; frontier = parent[unit];
    for (depth = 0; depth < 8 && frontier != ""; depth++) {
      next_frontier = "";
      n = split(frontier, q, " ");
      for (i = 1; i <= n; i++) {
        p = q[i];
        if (p == "" || index(seen, " " p " ")) continue;
        seen = seen " " p " ";
        if (sess[p] > 0) via = via (via == "" ? "" : ",") p;
        else next_frontier = next_frontier " " parent[p];
      }
      frontier = next_frontier;
    }
    # composed-only: every session of this unit also ran one of its callers. The
    # unit works, but has never been entered on its own, so its runs are really
    # the runs of that caller and a correction inside them may belong to either
    # file. evidence-analysis-core is the standing case — 1 session, and it
    # belongs to analytics-friction-analysis.
    cby = "";
    if (sess[unit] > 0 && via != "" && fl[unit] != "-" && fl[unit] != "") {
      vn = split(via, vs, ",");
      for (vi = 1; vi <= vn; vi++) {
        p = vs[vi];
        if (p == "" || p == unit || fl[p] == "" || fl[p] == "-") continue;
        mn = split(substr(fl[unit], 2, length(fl[unit]) - 2), mine, ",");
        ok = (mn > 0);
        for (mi = 1; mi <= mn; mi++)
          if (mine[mi] != "" && index(fl[p], "," mine[mi] ",") == 0) { ok = 0; break }
        if (ok) { cby = p; break }
      }
    }
    # Runs against the current text. With no known change date every run counts,
    # which is the right default for a unit git cannot see.
    rs = 0;
    if (chgd[unit] != "" && dts[unit] != "-" && dts[unit] != "") {
      n = split(dts[unit], dd, ",");
      for (i = 1; i <= n; i++) if (dd[i] > chgd[unit]) rs++;
    } else rs = sess[unit];
    # `unadopted` is testimony that the unit has NOT run: it must not promote
    # the verdict, but it must stop the unit reading as unmeasured and coming
    # back as a question every sweep.
    declined = (note[unit] ~ /^unadopted/);
    verdict = (cby != "")        ? "composed-only" \
            : (sess[unit] > 0)   ? "used" \
            : (sub_[unit] > 0)   ? "subagent-only" \
            : (artf[unit] > 0)   ? "artifact-only" \
            : declined           ? "unadopted" \
            : (said[unit] != "") ? "testimony" \
            : (via != "")        ? "reachable" : "no-evidence";
    if (said[unit] != "")
      via = via (via == "" ? "" : ",") "said:" (declined ? note[unit] : said[unit]);
    printf "%s\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
           unit, inv[unit], sess[unit], sub_[unit], artr[unit], artf[unit],
           (last[unit]=="" ? "-" : last[unit]),
           (chgd[unit]=="" ? "-" : chgd[unit]),
           (chgs[unit]=="" ? "-" : chgs[unit]),
           rs, (via == "" ? "-" : via), verdict, (cby == "" ? "-" : cby),
           (rvd[unit]=="" ? "-" : rvd[unit]),
           (rgd[unit]=="" ? "-" : rgd[unit]),
           (rgh[unit]=="" ? "-" : rgh[unit]),
           (rgn[unit]=="" ? "-" : rgn[unit]);
  }
' dtally="$WORK/direct-tally.tsv" atally="$WORK/artifact-tally.tsv" \
  chg="$WORK/changed.tsv" comp="$WORK/composition.txt" testim="$TESTIMONY" \
  rev="$WORK/reviewed.tsv" revgit="$WORK/reviewed-git.tsv" \
  "$WORK/direct-tally.tsv" "$WORK/artifact-tally.tsv" "$WORK/changed.tsv" \
  "$WORK/composition.txt" "$TESTIMONY" "$WORK/reviewed.tsv" "$WORK/reviewed-git.tsv" \
  "$WORK/units.txt" \
  | sort -k3,3nr -k5,5nr -k1,1 > "$WORK/rows.tsv"

if [ "$MODE" = json ]; then
  jq -R -s --arg root "$ART_ROOT" --arg tx "$TRANSCRIPTS" --arg ls "$LEDGER_STATUS" '
    { artifact_root: $root, transcripts: $tx, ledger_status: $ls,
      units: (split("\n") | map(select(length > 0) | split("\t") | {
        unit:            .[0],
        invocations:     (.[1] | tonumber),
        sessions:        (.[2] | tonumber),
        subagent:        (.[3] | tonumber),
        artifact_runs:   (.[4] | tonumber),
        artifact_files:  (.[5] | tonumber),
        last_run:        (if .[6] == "-" then null else .[6] end),
        changed:         (if .[7] == "-" then null else .[7] end),
        changed_subject: (if .[8] == "-" then null else .[8] end),
        runs_since:      (.[9] | tonumber),
        via:             (if .[10] == "-" then null else .[10] end),
        verdict:         .[11],
        composed_by:     (if .[12] == "-" then null else .[12] end),
        last_reviewed:     (if .[13] == "-" then null else .[13] end),
        reviewed_anywhere: (if .[14] == "-" then null else .[14] end),
        reviewed_host:     (if .[15] == "-" then null else .[15] end),
        reviewed_runs:     (if .[16] == "-" then null else (.[16] | tonumber) end) })) }' < "$WORK/rows.tsv"
  exit 0
fi

echo "# skill-inventory"
echo "# transcripts : $TRANSCRIPTS"
echo "# artifacts   : $ART_ROOT — $ART_N files across $REPO_N repo(s)"
echo "# ledger      : $ART_ROOT/skill-reviewer/LEDGER.md — $LEDGER_STATUS"
echo
{
  printf 'UNIT\tSESS\tSUB\tRUNS\tFILES\tLAST RUN\tREVIEWED\tANYWHERE\tSINCE\tVIA\tVERDICT\n'
  awk -F'\t' '{ printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                $1, $3, ($4>0?$4:"-"), ($5>0?$5:"-"), ($6>0?$6:"-"),
                $7, $14, ($15=="-" ? "-" : $15 "/" $16), $10, $11, $12 }' "$WORK/rows.tsv"
} | column -t -s "$(printf '\t')"

if [ -n "$LEDGER_STRAYS" ]; then
  echo
  echo "# MISPLACED LEDGERS — under a repo key, so NOT read. Move to the path above."
  printf '%s\n' "$LEDGER_STRAYS"
fi

AMBIG=$(grep -c '|' "$WORK/artifact-owned.tsv")
if [ "$AMBIG" -gt 0 ]; then
  echo
  echo "# AMBIGUOUS ARTIFACTS — attributable to a set, counted for nobody"
  grep '|' "$WORK/artifact-owned.tsv" | awk -F'\t' '{ printf "%s\t%s\n", $2, $1 }'
fi

if grep -q '^?' "$WORK/artifact-owned.tsv"; then
  echo
  echo "# UNMAPPED AREAS — extend the area map, or they stay invisible"
  grep '^?' "$WORK/artifact-owned.tsv" | awk -F'\t' '{ print $2 }'
fi

cat <<'EOF'

# COLUMNS
#   SESS     real sessions — the only thing that counts as a reviewable run
#   SUB      subagent invocations. Real uses, but no human, so never runs
#   RUNS     dated artifact reports. One run, so one report
#   FILES    every artifact file, byproducts included. FILES > RUNS is normal
#   REVIEWED newest ledger row for the unit. `-` means never reviewed on this
#            machine. Read the `ledger :` status in the header before reading a
#            column of dashes as "nothing has ever been reviewed": absent and
#            empty mean there is no ledger, unparsed means there IS one and it
#            did not parse, and split means rows are sitting under a repo key
#            where nothing will read them
#   SINCE    runs against the current text, i.e. since the last content change
#
# COVERAGE — all eight verdicts, and what each does and does not license
#   used          direct record exists in a real session. Safe to review.
#   composed-only every session of this unit also ran one of its callers, so it
#                 has never been entered on its own. Its runs are really the
#                 caller's, and a correction inside one may belong to either
#                 file — decide which before proposing an edit.
#   subagent-only every invocation came from a sidechain. The unit works and is
#                 reachable, but no human has ever gated it — nothing to mine.
#   artifact-only ran, but only composed or unrecorded. Runs are NOT countable;
#                 the artifact proves output shape, not which unit produced it.
#   testimony     the user reported it ran. Enough to stop calling it unused;
#                 not enough to review, because there is no gate evidence.
#   unadopted     the user reported it has NOT run. Asked and answered — do not
#                 raise it again as a question, and do not count it as unused
#                 data either.
#   reachable     a caller with runs exists. Says nothing about this unit firing.
#   no-evidence   no arm saw it. Means "not measured", never "not used". Ask
#                 before writing any of these down as unadopted.
EOF
