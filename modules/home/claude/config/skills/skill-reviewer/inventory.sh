#!/usr/bin/env bash
#
# Cross-arm usage inventory for every local skill and slash command.
#
#   bash inventory.sh
#
# Answers one question per unit: is there evidence it ran, and from which arm.
#
# Four arms, because no single one sees everything:
#
#   direct    — a Skill tool call or a slash command in the transcripts.
#               Blind to a skill executed inline by another skill.
#   artifact  — a dated report under $ARTIFACTS/<repo>/<area>/. Sees composed
#               runs the direct arm misses, but only for units that write
#               reports, and it attributes by convention rather than by record.
#   composed  — a caller with direct runs, via the verified composition graph.
#               Establishes reachability, never that a specific run happened.
#   testimony — testimony.txt: what the user reported when a machine arm was
#               wrong. The only arm that can see an inline run leaving no trace.
#
# A unit with no evidence in any arm is `no-evidence`, which is NOT the same as
# unused. Reporting it as unused is the exact mistake this script exists to stop.

set -uo pipefail

CONFIG_DIR="${SKILL_CONFIG_DIR:-$HOME/dotfiles/modules/home/claude/config}"
TRANSCRIPTS="${SKILL_TRANSCRIPT_DIR:-$HOME/.claude/projects}"
ART_ROOT="${SKILL_ARTIFACT_ROOT:-$HOME/.local/state/claude/artifacts}"
# Read testimony from the checkout when there is one. At runtime $0 is a
# /nix/store symlink, so the store copy is whatever the last `make rebuild`
# captured — a correction appended today would stay inert until the next one,
# and rebuilding requires quitting every session. The whole point of this file
# is to catch a correction the moment it is made, so the repo wins when present.
TESTIMONY="$CONFIG_DIR/skills/skill-reviewer/testimony.txt"
[ -f "$TESTIMONY" ] || TESTIMONY="$(dirname "$0")/testimony.txt"
[ -f "$TESTIMONY" ] || TESTIMONY=/dev/null

WORK="${TMPDIR:-/tmp}/skill-inventory"
mkdir -p "$WORK"

# --------------------------------------------------------------------------
# Composition graph: "child parent" per line.
#
# Verified 2026-08-17 by reading the invocation language in each SKILL.md, not
# by grepping for names. A name in a "NOT for this, use X" line is a disclaimer
# and must not become an edge — mis-reading those is what put four phantom
# children under config-health in an earlier draft of this graph.
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
pre-pr pre-pr-autonomous
feature-design-doc feature-spec
feature-plan feature-spec
permission-audit config-health
EOF

# --------------------------------------------------------------------------
# Direct arm.
#
# Both patterns are guarded against self-pollution. A session that *analyses*
# skill usage writes the search strings and their output into its own
# transcript, so an unguarded grep counts the analysis as a run. Measured
# 2026-08-17: unguarded matching inflated `investigate` by 4 sessions and
# `pre-pr-autonomous` by 1.
#
#   Skill tool     — the record must be an assistant turn carrying a tool_use
#                    named Skill. An echo of one lands in a tool_result.
#   Slash command  — message.content must be the string form, which only a
#                    real slash invocation produces. Echoes arrive as arrays.
# --------------------------------------------------------------------------
grep -rH '"type":"assistant"' "$TRANSCRIPTS" 2>/dev/null \
  | grep '"name":"Skill"' \
  | awk -F'.jsonl:' 'NF>1 {
      f=$1; m=$2;
      while (match(m, /"skill":"[a-z0-9-]+"/)) {
        print substr(m, RSTART+9, RLENGTH-10) "\t" f;
        m = substr(m, RSTART+RLENGTH);
      }
    }' > "$WORK/direct.tsv"

grep -rH '"content":"<command-message>' "$TRANSCRIPTS" 2>/dev/null \
  | awk -F'.jsonl:' 'NF>1 {
      f=$1; m=$2;
      while (match(m, /<command-name>\/[a-z0-9-]+<\/command-name>/)) {
        print substr(m, RSTART+15, RLENGTH-30) "\t" f;
        m = substr(m, RSTART+RLENGTH);
      }
    }' >> "$WORK/direct.tsv"

sort "$WORK/direct.tsv" | uniq -c \
  | awk '{ inv[$2] += $1; sess[$2]++ } END { for (k in inv) print k "\t" inv[k] "\t" sess[k] }' \
  > "$WORK/direct-tally.tsv"

# --------------------------------------------------------------------------
# Artifact arm.
#
# One root, laid out as <repo>/<area>/<file>, keyed on the git remote name so
# every worktree of a repo lands in the same place. This used to scan
# <repo-root>/docs/local across each checkout and deduplicate on
# (area, filename), because worktrunk copies that directory into every worktree
# and one report showed up four times across siblings. Moving the store out of
# the repo removed the copies, and the dedup pass with them.
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
    # State belonging to this reviewer, not a run artifact. Counting the ledger
    # as evidence would have the loop measuring itself. (No apostrophes in here
    # — the whole awk program is inside a single-quoted shell string.)
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
    print owner "\t" area "/" file;
  }' "$WORK/artifact-keys.txt" > "$WORK/artifact-owned.tsv"

grep -v '|' "$WORK/artifact-owned.tsv" | grep -v '^?' \
  | awk -F'\t' '{ n[$1]++ } END { for (k in n) print k "\t" n[k] }' \
  > "$WORK/artifact-tally.tsv"

# --------------------------------------------------------------------------
# Units, then the table.
# --------------------------------------------------------------------------
{ ls -1 "$CONFIG_DIR/skills"; ls -1 "$CONFIG_DIR/commands" | sed 's/\.md$//'; } \
  | sed 's#/$##' | sort -u > "$WORK/units.txt"

echo "# skill-inventory"
echo "# transcripts : $TRANSCRIPTS"
echo "# artifacts   : $ART_ROOT — $ART_N files across $REPO_N repo(s)"
echo
printf 'UNIT\tDIRECT\tSESS\tARTIFACTS\tVIA\tVERDICT\n'

awk -F'\t' '
  FNR==NR && FILENAME==dtally { inv[$1]=$2; sess[$1]=$3; next }
  FILENAME==atally            { art[$1]=$2; next }
  FILENAME==comp              { split($0, e, " "); parent[e[1]] = parent[e[1]] " " e[2]; next }
  FILENAME==testim            { if ($0 ~ /^#/ || $0 == "") next;
                                split($0, t, " ");
                                said[t[1]] = t[2]; note[t[1]] = t[3]; next }
  {
    unit = $1;
    # Transitive reachability: a caller counts if it has direct runs, or if
    # something that calls *it* does. Fixpoint over a graph this small is free.
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
    # An `unadopted` note is testimony that the unit has NOT run, so it must not
    # promote the verdict — but it must stop the unit reading as unmeasured,
    # which is what would put it back on the ask-about list every sweep.
    declined = (note[unit] ~ /^unadopted/);
    verdict = (sess[unit] > 0)               ? "used" \
            : (art[unit] > 0)                ? "artifact-only" \
            : declined                       ? "unadopted" \
            : (said[unit] != "")             ? "testimony" \
            : (via != "")                    ? "reachable" : "no-evidence";
    if (said[unit] != "")
      via = via (via == "" ? "" : ",") "said:" (declined ? note[unit] : said[unit]);
    printf "%s\t%d\t%d\t%s\t%s\t%s\n", unit, inv[unit], sess[unit],
           (art[unit] > 0 ? art[unit] : "-"), (via == "" ? "-" : via), verdict;
  }
' dtally="$WORK/direct-tally.tsv" atally="$WORK/artifact-tally.tsv" \
  comp="$WORK/composition.txt" testim="$TESTIMONY" \
  "$WORK/direct-tally.tsv" "$WORK/artifact-tally.tsv" "$WORK/composition.txt" \
  "$TESTIMONY" "$WORK/units.txt" \
  | sort -k3,3nr -k4,4r -k1,1

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

# COVERAGE — what each verdict does and does not license
#   used          direct record exists. Safe to review.
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
