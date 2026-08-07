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
CFG="$REPO/nix/modules/home/claude/config"

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

# --- Check 2: custom skill/command <-> Skill() allowlist drift -----------------
# Every custom skill and command needs a matching Skill(<name>) allow entry or it
# prompts on first use in every new worktree. Plugin skills are namespaced and
# covered by their own globs, so only bare (unnamespaced) entries are compared.
check_skill_drift() {
  local disk allowed
  disk=$( { [[ -d "$CFG/skills" ]] && find "$CFG/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;
            [[ -d "$CFG/commands" ]] && find "$CFG/commands" -maxdepth 1 -name '*.md' -exec basename {} .md \; ; } | sort -u)
  allowed=$(jq -r '.permissions.allow[] | select(startswith("Skill(")) | ltrimstr("Skill(") | rtrimstr(")")' \
            "$SETTINGS" 2>/dev/null | grep -v ':' | sort -u)

  # Guard: an unreadable/empty allowlist would otherwise report EVERY skill as
  # missing -- a wall of confident false positives. Bail loudly instead.
  if [[ -z "$allowed" ]]; then
    emit REVIEW skill-drift "could not read any Skill() entries from $SETTINGS — skipping drift check rather than reporting every skill as missing"
    return
  fi

  local missing stale
  missing=$(comm -23 <(printf '%s\n' "$disk") <(printf '%s\n' "$allowed"))
  stale=$(comm -13 <(printf '%s\n' "$disk") <(printf '%s\n' "$allowed"))

  if [[ -n "$missing" ]]; then
    while read -r s; do
      [[ -z "$s" ]] && continue
      emit FAIL skill-drift "'$s' exists on disk with no Skill($s) allow entry — prompts on first use in every new worktree"
    done <<<"$missing"
  fi
  if [[ -n "$stale" ]]; then
    while read -r s; do
      [[ -z "$s" ]] && continue
      emit REVIEW skill-drift "Skill($s) is allowlisted but no such skill/command is on disk — stale entry or renamed skill"
    done <<<"$stale"
  fi
  [[ -z "$missing$stale" ]] && emit OK skill-drift "every custom skill and command has a matching Skill() allow entry"
}

# --- Check 3: allow rules neutralised by deny ---------------------------------
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

# --- Check 4: hook registration and executability -----------------------------
# An out-of-store symlink means an edited hook is live immediately, but a NEW
# hook does nothing until a rebuild registers it. A non-executable hook fails
# silently, which is the worst case.
check_hooks() {
  local registered on_disk missing_reg orphan
  registered=$(jq -r '.hooks | to_entries[] | .value[] | .hooks[]?.command // empty' "$SETTINGS" 2>/dev/null \
               | sed 's|.*/||' | sort -u)
  on_disk=$([[ -d "$CFG/hooks" ]] && find "$CFG/hooks" -maxdepth 1 -name '*.sh' -exec basename {} \; | sort -u)

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

check_symlink
check_skill_drift
check_dead_allows
check_hooks
exit 0
