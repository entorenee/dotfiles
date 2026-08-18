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
[ "${1:-}" = "--json" ] && MODE=json

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
feature-design-doc feature-spec
feature-plan feature-spec
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
      | awk -v u="$u" '
          /^C/ { d = substr($1, 2); s = substr($0, index($0, " ") + 1); next }
          NF == 3 && ($1 + $2) > 0 { printf "%s\t%s\t%s\n", u, d, s; exit }'
  done < "$WORK/units.txt" >> "$WORK/changed.tsv"
fi

# --------------------------------------------------------------------------
# Artifact arm.
#
# One root, laid out as <repo>/<area>/<file>, keyed on the git remote name so
# every worktree of a repo lands in the same place.
# --------------------------------------------------------------------------
find "$ART_ROOT" -mindepth 3 -maxdepth 3 -type f 2>/dev/null > "$WORK/artifact-files.txt"
ART_N=$(wc -l < "$WORK/artifact-files.txt" | tr -d ' ')
REPO_N=$(find "$ART_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')

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
    else if (area == "plans") {
      if      (low ~ /design/)            owner = "feature-design-doc";
      else if (low ~ /(-plan|-qa)\.md$/)  owner = "feature-plan";
      else owner = "feature-plan|feature-design-doc|feature-spec";
    }
    else if (area == "reviews") {
      if      (low ~ /^pre-pr-/)  owner = "pre-pr";
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
#      runs_since via verdict
# --------------------------------------------------------------------------
awk -F'\t' '
  FILENAME==dtally { inv[$1]=$2; sess[$1]=$3; sub_[$1]=$4; last[$1]=$5; dts[$1]=$6;
                     fl[$1]=$7; next }
  FILENAME==atally { artf[$1]=$2; artr[$1]=$3; next }
  FILENAME==chg    { chgd[$1]=$2; chgs[$1]=$3; next }
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
    printf "%s\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%d\t%s\t%s\t%s\n",
           unit, inv[unit], sess[unit], sub_[unit], artr[unit], artf[unit],
           (last[unit]=="" ? "-" : last[unit]),
           (chgd[unit]=="" ? "-" : chgd[unit]),
           (chgs[unit]=="" ? "-" : chgs[unit]),
           rs, (via == "" ? "-" : via), verdict, (cby == "" ? "-" : cby);
  }
' dtally="$WORK/direct-tally.tsv" atally="$WORK/artifact-tally.tsv" \
  chg="$WORK/changed.tsv" comp="$WORK/composition.txt" testim="$TESTIMONY" \
  "$WORK/direct-tally.tsv" "$WORK/artifact-tally.tsv" "$WORK/changed.tsv" \
  "$WORK/composition.txt" "$TESTIMONY" "$WORK/units.txt" \
  | sort -k3,3nr -k5,5nr -k1,1 > "$WORK/rows.tsv"

if [ "$MODE" = json ]; then
  jq -R -s --arg root "$ART_ROOT" --arg tx "$TRANSCRIPTS" '
    { artifact_root: $root, transcripts: $tx,
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
        composed_by:     (if .[12] == "-" then null else .[12] end) })) }' < "$WORK/rows.tsv"
  exit 0
fi

echo "# skill-inventory"
echo "# transcripts : $TRANSCRIPTS"
echo "# artifacts   : $ART_ROOT — $ART_N files across $REPO_N repo(s)"
echo
{
  printf 'UNIT\tSESS\tSUB\tRUNS\tFILES\tLAST RUN\tSINCE\tVIA\tVERDICT\n'
  awk -F'\t' '{ printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                $1, $3, ($4>0?$4:"-"), ($5>0?$5:"-"), ($6>0?$6:"-"),
                $7, $10, $11, $12 }' "$WORK/rows.tsv"
} | column -t -s "$(printf '\t')"

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
#   SESS   real sessions — the only thing that counts as a reviewable run
#   SUB    subagent invocations. Real uses, but no human, so never runs
#   RUNS   dated artifact reports. One run, so one report
#   FILES  every artifact file, byproducts included. FILES > RUNS is normal
#   SINCE  runs against the current text, i.e. since the last content change
#
# COVERAGE — what each verdict does and does not license
#   used          direct record exists in a real session. Safe to review.
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
