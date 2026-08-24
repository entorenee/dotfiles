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
# Left empty rather than defaulted when unset: this script never hard-fails, so
# check_skill_inventory reports the gap as REVIEW rather than guessing a path
# and announcing a missing ledger that may well exist elsewhere.
ARTIFACTS="${ARTIFACTS:-${MY_CLAUDE_ARTIFACTS_ROOT:+$MY_CLAUDE_ARTIFACTS_ROOT/dotfiles}}"

emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# Checks 2 and 3 read their expected state out of settings.json, so an
# unreadable one makes their queries return empty — which reads as "nothing
# wrong" for check 2 and as "every hook is unregistered" for check 3. Both are
# false, and both fire in exactly the scenario check 1 exists to catch. Same
# guard idiom as check_hooks' empty-$on_disk case: say what could not be
# checked rather than asserting on a file that was never read.
settings_readable() { jq -e . "$SETTINGS" >/dev/null 2>&1; }

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
  if ! settings_readable; then
    emit REVIEW dead-allow "settings.json is unreadable (see the symlink finding above), so the allow/deny lists could not be compared — this check is skipped, not passed"
    return
  fi
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
  if ! settings_readable; then
    emit REVIEW hooks "settings.json is unreadable (see the symlink finding above), so hook registration could not be read — reporting every hook as unregistered would name the wrong fix. Restore settings.json first, then re-run."
    return
  fi
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
# Structural only. Whether a skill is *working* is behavioural and belongs to
# /system-review; folding it in here is what "When NOT to Use" warns against.
check_skill_inventory() {
  local units ledger rows untracked orphans unreviewed n

  if [[ ! -d "$CFG/skills" ]]; then
    emit REVIEW skill-inventory "no skills directory under $CFG — check that CFG points at the live config tree"
    return
  fi

  # A unit is a skills/ dir holding a SKILL.md, or a commands/*.md — not a bare
  # directory listing, which picks up stray empty dirs and reports them broken.
  units=$( { find "$CFG/skills" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null \
               | sed "s#^$CFG/skills/##; s#/SKILL.md\$##"
             ls -1 "$CFG/commands" 2>/dev/null | sed 's/\.md$//'; } | sort -u )

  # A unit git does not track is invisible to flake eval, so default.nix never
  # generates its Skill(<name>) rule and it prompts on first use while looking
  # correctly installed.
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
      emit FAIL skill-inventory "$u is untracked ($f) — flake eval cannot see it, so no Skill($u) permission is generated and it prompts on first use. Ask the user to stage it — staging is theirs — then rebuild."
    done <<<"$units"
  fi

  if [[ -z "$ARTIFACTS" ]]; then
    emit REVIEW skill-inventory "MY_CLAUDE_ARTIFACTS_ROOT is unset, so the review ledger cannot be located — run 'make rebuild', then start a new session. Ledger checks skipped."
    [[ -z "$untracked" ]] && emit OK skill-inventory "tracking verified for $(printf '%s\n' "$units" | grep -c .) unit(s)"
    return
  fi

  ledger="$ARTIFACTS/skill-reviewer/LEDGER.md"
  if [[ ! -f "$ledger" ]]; then
    emit REVIEW skill-inventory "no review ledger at $ledger — it is machine-local and lives outside the repo, so a fresh machine legitimately has none. Baselines must be re-derived before any delta is claimed."
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

  # One counted line, not one per unit: most are legitimately below the review
  # threshold, and a wall of REVIEW rows would bury the two findings above.
  unreviewed=$(comm -23 <(printf '%s\n' "$units") <(printf '%s\n' "$rows"))
  n=$(printf '%s\n' "$unreviewed" | grep -c .)
  if [[ $n -gt 0 ]]; then
    emit REVIEW skill-inventory "$n of $(printf '%s\n' "$units" | grep -c .) units have no ledger row (e.g. $(printf '%s' "$unreviewed" | head -4 | tr '\n' ' ')) — expected while the cadence is young; run /system-review to see which have crossed their threshold"
  fi

  [[ -z "$untracked$orphans" ]] \
    && emit OK skill-inventory "all units tracked; every ledger row names a live unit"
}

check_symlink
# --- Check 5: MCP rule / server reconciliation --------------------------------
# JSON-only, so it runs without authenticating anything. That bounds it: this
# arm reconciles rules against *declared servers*, never against a server's
# actual tool names. Tool-name drift needs a live authenticated roster and is
# handed to the rubric instead -- an allowlist can match nothing at all while
# every server is correctly configured, and no amount of JSON reveals it.
#
# Two prefix forms carry meaning and must not be conflated:
#   mcp__plugin_claude-code-home-manager_<name>__  a Nix-declared server; lives
#     in the plugin's .mcp.json in the store, NOT in ~/.claude.json
#   mcp__<name>__                                  a server added by `claude mcp
#     add`; lives in ~/.claude.json
# So a bare-prefix rule is checkable against ~/.claude.json and a plugin-prefix
# rule is not. Checking the latter against ~/.claude.json reports every
# Nix-declared server as missing.
check_mcp_rules() {
  local cj="$HOME/.claude.json"
  if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
    emit REVIEW mcp-rules "settings.json is unreadable (see the symlink finding above), so MCP rules could not be read — skipped, not passed"
    return
  fi
  if ! jq -e . "$cj" >/dev/null 2>&1; then
    emit REVIEW mcp-rules "$cj is unreadable, so hand-added servers cannot be enumerated — skipped, not passed"
    return
  fi

  local user_servers proj_pairs rules bare_servers findings=0
  user_servers=$(jq -r '(.mcpServers // {}) | keys[]?' "$cj" 2>/dev/null | sort -u)
  proj_pairs=$(jq -r '(.projects // {}) | to_entries[] | .key as $p | ((.value.mcpServers // {}) | keys[]?) | "\(.)\t\($p)"' "$cj" 2>/dev/null)
  rules=$(jq -r '[.permissions.allow[]?, .permissions.deny[]?] | .[] | select(startswith("mcp__"))' "$SETTINGS" 2>/dev/null)
  bare_servers=$(sed -n 's/^mcp__\([^_][^_]*\)__.*/\1/p' <<<"$rules" | grep -v '^plugin_' | sort -u)

  # A project-scoped server resolves in that repo and nowhere else, with no
  # error anywhere else. `claude mcp add` defaults to --scope local, so this is
  # the shape a correct-looking command produces.
  local srv path
  while IFS=$'\t' read -r srv path; do
    [[ -z "$srv" ]] && continue
    if grep -qxF "$srv" <<<"$user_servers"; then
      emit FAIL mcp-rules "'$srv' is declared BOTH at user scope and under projects[\"$path\"] in ~/.claude.json — two registrations of one server. Remove the project-scoped copy with 'claude mcp remove $srv' from that directory."
    else
      emit REVIEW mcp-rules "'$srv' is declared only under projects[\"$path\"] in ~/.claude.json, so it resolves in that directory and is silently absent everywhere else. If it is meant to be available generally, re-add it with --scope user."
    fi
    findings=$((findings + 1))
  done <<<"$proj_pairs"

  # A bare-prefix rule names a server that must be in ~/.claude.json. Absent
  # means the rule matches nothing -- the state left behind by removing a
  # server without removing its rules.
  while read -r srv; do
    [[ -z "$srv" ]] && continue
    grep -qxF "$srv" <<<"$user_servers" && continue
    grep -qF "$srv"$'\t' <<<"$proj_pairs" && continue
    emit FAIL mcp-rules "permissions rules reference 'mcp__${srv}__*' but no server named '$srv' is declared in ~/.claude.json — the rules match nothing. Either the server was removed and its rules were not, or it is Nix-declared and the rules need the mcp__plugin_claude-code-home-manager_${srv}__ prefix."
    findings=$((findings + 1))
  done <<<"$bare_servers"

  # A declared server with no rules is not broken; every call to it prompts.
  # Reported because the cost is invisible -- nothing errors, it just asks.
  while read -r srv; do
    [[ -z "$srv" ]] && continue
    grep -q "^mcp__${srv}__" <<<"$rules" && continue
    emit REVIEW mcp-rules "'$srv' is declared in ~/.claude.json with no mcp__${srv}__ rule, so every call to it prompts. Zero rules is correct for a server whose whole surface is one dispatcher tool; otherwise it is a gap."
    findings=$((findings + 1))
  done <<<"$user_servers"

  emit REVIEW mcp-rules "$(grep -c . <<<"$rules") MCP rule(s) checked against declared servers only. Whether each rule matches a tool the server actually offers is NOT checked here — it needs a live authenticated roster. Hand that to the rubric; do not read this line as tool-name coverage."
  [[ $findings -eq 0 ]] && emit OK mcp-rules "every MCP rule names a declared server, and every declared server has at least one rule"
}

check_dead_allows
check_hooks
check_skill_inventory
check_mcp_rules
exit 0
