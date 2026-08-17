#!/usr/bin/env bash
# Deterministic config-health checks.
#
# Every line printed here is a FACT read off disk, never an inference. Findings
# are tab-separated: STATUS<TAB>CHECK<TAB>DETAIL
#   OK     — verified good, no action
#   FAIL   — provably broken, act on it
#   REVIEW — needs human eyes; the script cannot decide (never assert on these)
#
# Exit status is always 0: a FAIL is a finding to report, not a script error.

set -uo pipefail

SETTINGS="${SETTINGS:-$HOME/.claude/settings.json}"
REPO="${REPO:-$HOME/dotfiles}"
CFG="$REPO/modules/home/claude/config"

emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# --- Check 1: settings.json symlink integrity ---------------------------------
# The documented failure mode: a rebuild during a live session unlinks this file
# and every permission rule vanishes silently. Missing file, not malformed one.
check_symlink() {
  local n
  if [[ ! -e "$SETTINGS" ]]; then
    emit FAIL symlink "settings.json MISSING at $SETTINGS — all permission rules are gone. Quit every session, re-run 'make rebuild'."
    return
  fi
  if ! n=$(jq -e '.permissions.allow | length' "$SETTINGS" 2>/dev/null); then
    emit FAIL symlink "settings.json unreadable or has no permissions.allow"
    return
  fi
  emit OK symlink "settings.json resolves; $n allow / $(jq '.permissions.deny|length' "$SETTINGS") deny rules live"
}

# --- Check 2: allow rules neutralised by deny ---------------------------------
# Deny always wins, so an allow entry contradicted by a deny is dead weight.
# Only EXACT duplicates are provable here. Same-head pairs are surfaced for human
# review because deciding glob-language containment is not something this script
# can do soundly -- and a false "dead rule" claim is worse than no claim.
check_dead_allows() {
  local dead heads
  dead=$(jq -r '[.permissions.allow[]] - ([.permissions.allow[]] - [.permissions.deny[]]) | .[]' "$SETTINGS" 2>/dev/null)
  if [[ -n "$dead" ]]; then
    while read -r r; do
      [[ -z "$r" ]] && continue
      emit FAIL dead-allow "$r is in BOTH allow and deny — deny wins, so the allow entry is dead weight"
    done <<<"$dead"
  fi

  # Same tool + same first command word on both lists: legitimate narrowing
  # (broad allow + targeted deny) OR an accidental shadow. Human decides.
  local head_expr='select(test("^[A-Za-z]+\\(")) | (split("(")[0] + "(" + (split("(")[1] // "" | split(" ")[0] | split(")")[0]))'
  heads=$(comm -12 \
    <(jq -r ".permissions.allow[] | $head_expr" "$SETTINGS" | sort -u) \
    <(jq -r ".permissions.deny[]  | $head_expr" "$SETTINGS" | sort -u))
  if [[ -n "$heads" ]]; then
    local c; c=$(printf '%s\n' "$heads" | grep -c . )
    emit REVIEW dead-allow "$c command head(s) appear on both lists (e.g. $(printf '%s' "$heads" | head -3 | tr '\n' ' ')) — expected for broad-allow + targeted-deny, but confirm each narrowing is intended"
  fi

  [[ -z "$dead" ]] && emit OK dead-allow "no allow rule is exactly duplicated in deny"
}

# --- Check 3: hook registration and executability -----------------------------
# An out-of-store symlink means an edited hook is live immediately, but a NEW
# hook does nothing until a rebuild registers it. A non-executable hook fails
# silently, which is the worst case.
check_hooks() {
  local registered on_disk missing_reg orphan
  registered=$(jq -r '.hooks | to_entries[] | .value[] | .hooks[]?.command // empty' "$SETTINGS" 2>/dev/null \
               | sed 's|.*/||' | sort -u)
  on_disk=$([[ -d "$CFG/hooks" ]] && find "$CFG/hooks" -maxdepth 1 -name '*.sh' -exec basename {} \; | sort -u)

  # An empty $on_disk almost always means CFG is wrong, not that every hook was
  # deleted. Without this guard a stale CFG reports each registered hook as
  # "every trigger errors" — alarming, and entirely false. Not hypothetical:
  # CFG kept a "$REPO/nix/..." prefix after the tree was lifted to the repo
  # root, and one run reported all 4 hooks missing when every one was present.
  if [[ -z "$on_disk" ]]; then
    emit REVIEW hooks "no hook scripts found under $CFG/hooks — check that CFG points at the live config tree; skipping rather than reporting every registered hook as orphaned"
    return
  fi

  missing_reg=$(comm -23 <(printf '%s\n' "$on_disk") <(printf '%s\n' "$registered"))
  orphan=$(comm -13 <(printf '%s\n' "$on_disk") <(printf '%s\n' "$registered"))

  while read -r h; do
    [[ -z "$h" ]] && continue
    emit FAIL hooks "$h exists in config/hooks/ but is not registered in settings.json — it never fires; add it to default.nix and rebuild"
  done <<<"$missing_reg"

  while read -r h; do
    [[ -z "$h" ]] && continue
    emit FAIL hooks "$h is registered in settings.json but has no file in config/hooks/ — every trigger errors"
  done <<<"$orphan"

  local nonexec=0
  while read -r h; do
    [[ -z "$h" ]] && continue
    if [[ ! -x "$CFG/hooks/$h" ]]; then
      emit FAIL hooks "$h is registered but NOT executable — it fails silently on every trigger"
      nonexec=1
    fi
  done <<<"$on_disk"

  [[ -z "$missing_reg$orphan" && $nonexec -eq 0 ]] \
    && emit OK hooks "all $(printf '%s\n' "$on_disk" | grep -c .) hook scripts registered and executable"
}

# --- Check 4: skill inventory drift -------------------------------------------
# Structural only, and deliberately so. Whether a skill is *working* is a
# behavioural question that belongs to /system-review, which owns the transcript
# arms and the run thresholds. Folding that in here is what this skill's own
# "When NOT to Use" warns produces a report nobody acts on. Everything below is
# provable off disk in milliseconds.
check_skill_inventory() {
  local units ledger rows untracked orphans unreviewed n

  if [[ ! -d "$CFG/skills" ]]; then
    emit REVIEW skill-inventory "no skills directory under $CFG — check that CFG points at the live config tree"
    return
  fi

  # A unit is a skills/ directory holding a SKILL.md, or a commands/*.md. Do not
  # substitute a bare directory listing: stray empty directories (a tool that
  # chdir'd there, say) are not units, and reporting one as a broken skill is
  # exactly the false alarm the hooks check above already learned to avoid.
  units=$( { find "$CFG/skills" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null \
               | sed "s#^$CFG/skills/##; s#/SKILL.md\$##"
             ls -1 "$CFG/commands" 2>/dev/null | sed 's/\.md$//'; } | sort -u )

  # A unit that git does not track is invisible to flake eval, so default.nix
  # never generates its Skill(<name>) rule and it prompts on first use while
  # looking correctly installed. Verified failure, 2026-08-10:
  # Skill(comment-review) was absent from the derived allowlist until the
  # directory was staged, then appeared immediately.
  # Same guard as check_hooks: if REPO is not a git checkout, every single unit
  # comes back untracked and the report screams that the whole skills tree is
  # broken. Say what could not be checked instead.
  untracked=""
  if ! git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    # Same guard as check_hooks: without this, a REPO that is not a checkout
    # reports every unit as broken. Say what could not be checked instead.
    emit REVIEW skill-inventory "$REPO is not a git checkout — cannot verify that units are tracked, so Skill() permission generation is unverified here"
  else
    while read -r u; do
      [[ -z "$u" ]] && continue
      local f
      if   [[ -f "$CFG/skills/$u/SKILL.md" ]]; then f="modules/home/claude/config/skills/$u/SKILL.md"
      elif [[ -f "$CFG/commands/$u.md"     ]]; then f="modules/home/claude/config/commands/$u.md"
      else continue; fi
      git -C "$REPO" ls-files --error-unmatch -- "$f" >/dev/null 2>&1 && continue
      untracked="$untracked $u"
      emit FAIL skill-inventory "$u is untracked ($f) — flake eval cannot see it, so no Skill($u) permission is generated and it prompts on first use. 'git add' it, then rebuild."
    done <<<"$units"
  fi

  ledger="$REPO/docs/local/skill-reviewer/LEDGER.md"
  if [[ ! -f "$ledger" ]]; then
    emit REVIEW skill-inventory "no review ledger at $ledger — it is git-ignored and machine-local, so a fresh checkout legitimately has none. Baselines must be re-derived before any delta is claimed."
    [[ -z "$untracked" ]] && emit OK skill-inventory "tracking verified for $(printf '%s\n' "$units" | grep -c .) unit(s)"
    return
  fi

  rows=$(grep -oE '^## [a-z0-9-]+' "$ledger" 2>/dev/null | sed 's/^## //' | sort -u)

  # A ledger row for a unit that no longer exists is real drift: a review whose
  # subject was renamed or deleted, still presenting as a live baseline.
  orphans=$(comm -13 <(printf '%s\n' "$units") <(printf '%s\n' "$rows"))
  while read -r r; do
    [[ -z "$r" ]] && continue
    emit FAIL skill-inventory "ledger has a row for '$r', which is neither a skill nor a command — renamed or deleted. Retire the row or restore the unit."
  done <<<"$orphans"

  # Never-reviewed units are reported as one counted line, not one line each.
  # Most units are legitimately below the review threshold, so a wall of REVIEW
  # rows here would bury the two findings above.
  unreviewed=$(comm -23 <(printf '%s\n' "$units") <(printf '%s\n' "$rows"))
  n=$(printf '%s\n' "$unreviewed" | grep -c .)
  if [[ $n -gt 0 ]]; then
    emit REVIEW skill-inventory "$n of $(printf '%s\n' "$units" | grep -c .) units have no ledger row (e.g. $(printf '%s' "$unreviewed" | head -4 | tr '\n' ' ')) — expected while the cadence is young; run /system-review to see which have crossed their threshold"
  fi

  [[ -z "$untracked$orphans" ]] \
    && emit OK skill-inventory "all units tracked; every ledger row names a live unit"
}

check_symlink
check_dead_allows
check_hooks
check_skill_inventory
exit 0
