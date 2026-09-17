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

MODE=run
case "${1:-}" in
  --selftest) MODE=selftest ;;
esac

SETTINGS="${SETTINGS:-$HOME/.claude/settings.json}"
REPO="${REPO:-$HOME/dotfiles}"
# Overridable so --selftest can point each check at a fixture tree. Every one
# defaults to the live path, so an unset environment behaves exactly as before.
CFG="${CFG:-$REPO/modules/home/claude/config}"
CLAUDE_JSON="${CLAUDE_JSON:-$HOME/.claude.json}"
# The root, not `$ARTIFACTS` — that name means the repo-keyed
# `$MY_CLAUDE_ARTIFACTS_ROOT/<repo>` everywhere else, and the review ledger sits
# above the repo layout. Named as `inventory.sh` names it, since both read it.
#
# Left empty rather than defaulted when unset: this script never hard-fails, so
# check_skill_inventory reports the gap as REVIEW rather than guessing a path
# and announcing a missing ledger that may well exist elsewhere.
ART_ROOT="${ART_ROOT:-${MY_CLAUDE_ARTIFACTS_ROOT:-}}"

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

  if [[ -z "$ART_ROOT" ]]; then
    emit REVIEW skill-inventory "MY_CLAUDE_ARTIFACTS_ROOT is unset, so the review ledger cannot be located — run 'make rebuild', then start a new session. Ledger checks skipped."
    [[ -z "$untracked" ]] && emit OK skill-inventory "tracking verified for $(printf '%s\n' "$units" | grep -c .) unit(s)"
    return
  fi

  ledger="$ART_ROOT/skill-reviewer/LEDGER.md"
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
  #
  # Scoped to this machine, because the ledger is. A unit reviewed on another
  # host has no row here and would otherwise be reported as never reviewed —
  # the same false-global claim the sweep notifier used to make. The review
  # record that IS shared lives in the commit trailers `inventory.sh` reads;
  # `/system-review` is where that gets compared, so point at it rather than
  # re-deriving it in a second script.
  unreviewed=$(comm -23 <(printf '%s\n' "$units") <(printf '%s\n' "$rows"))
  n=$(printf '%s\n' "$unreviewed" | grep -c .)
  if [[ $n -gt 0 ]]; then
    emit REVIEW skill-inventory "$n of $(printf '%s\n' "$units" | grep -c .) units have no ledger row on this machine (e.g. $(printf '%s' "$unreviewed" | head -4 | tr '\n' ' ')) — expected while the cadence is young, and a unit reviewed on another host has no row here either; run /system-review, which reads the shared record, to see which have crossed their threshold"
  fi

  [[ -z "$untracked$orphans" ]] \
    && emit OK skill-inventory "all units tracked; every ledger row names a live unit"
}

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
  local cj="$CLAUDE_JSON"
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

if [ "$MODE" = selftest ]; then
  # Every fixture models a failure that has happened, or that the check's own
  # comment names as its reason for existing. `doc-coherence.sh` cut two checks
  # that could not reproduce their known instance; the same bar applies here, so
  # the job of this harness is to prove each check can still fail.
  T="${TMPDIR:-/tmp}/config-health-selftest"; rm -rf "$T"; mkdir -p "$T"
  RAW="$T/raw.tsv"
  pass=0; fail=0

  verdict() { # $1 = label, $2 = expected, $3 = got
    if [ "$3" = "$2" ]; then pass=$((pass+1)); printf '  ok    %s\n' "$1"
    else fail=$((fail+1)); printf '  FAIL  %s — expected "%s", got "%s"\n' "$1" "$2" "$3"; fi
  }

  # Assertions land on the STATUS:CHECK enum, never on prose — a suite that
  # breaks every time a detail line is reworded stops being run.
  probe() { # $1 = check function, $2 = file to keep the raw TSV in
    "$1" >"$2"
    awk -F'\t' '{printf "%s:%s,", $1, $2}' "$2"
  }
  # Where two findings share a status and differ only in the fix they name, the
  # enum alone cannot tell them apart. This pins one phrase of the detail for
  # exactly those cases, and nothing more of it.
  detail_has() { # $1 = collapsed pairs, $2 = substring ("" = nothing to pin)
    if [ -n "$2" ] && ! grep -qF "$2" "$RAW"; then printf '%s detail!~%s' "$1" "$2"
    else printf '%s' "$1"; fi
  }

  # --- check_symlink ----------------------------------------------------------
  symcheck() { # $1 = label, $2 = expected, $3 = SETTINGS, $4 = detail substring
    local got
    got=$( SETTINGS=$3; probe check_symlink "$RAW" )
    verdict "$1" "$2" "$(detail_has "$got" "${4:-}")"
  }

  printf '{"permissions":{"allow":["Bash(ls *)"],"deny":["Bash(rm -rf *)"]}}\n' >"$T/settings-good.json"
  printf 'not json at all\n' >"$T/settings-broken.json"

  # The documented rebuild-during-a-live-session failure: a running session
  # unlinks the file and every permission rule goes with it. Missing, not
  # malformed — which is why the two cases below must stay distinguishable.
  symcheck "an absent settings.json fails as MISSING" \
    "FAIL:symlink," "$T/none.json" "MISSING"
  symcheck "a readable settings.json passes" \
    "OK:symlink," "$T/settings-good.json"
  # Different fix: re-running the rebuild restores an unlinked file and does
  # nothing for a malformed one.
  symcheck "malformed JSON fails as unreadable, not as missing" \
    "FAIL:symlink," "$T/settings-broken.json" "unreadable"

  # --- check_dead_allows ------------------------------------------------------
  deadcheck() { # $1 = label, $2 = expected, $3 = SETTINGS, $4 = detail substring
    local got
    got=$( SETTINGS=$3; probe check_dead_allows "$RAW" )
    verdict "$1" "$2" "$(detail_has "$got" "${4:-}")"
  }

  printf '{"permissions":{"allow":["Bash(git add*)"],"deny":["Bash(git add*)"]}}\n' >"$T/dead-dup.json"
  printf '{"permissions":{"allow":["Bash(git status)"],"deny":["Bash(rm -rf *)"]}}\n' >"$T/dead-disjoint.json"

  # The head-overlap REVIEW necessarily accompanies an exact duplicate — a rule
  # duplicated verbatim shares its own command head. Both lines are asserted so
  # that stays a stated consequence rather than a surprise.
  deadcheck "a rule on both lists is reported dead" \
    "FAIL:dead-allow,REVIEW:dead-allow," "$T/dead-dup.json" "in BOTH allow and deny"
  deadcheck "disjoint allow and deny pass" \
    "OK:dead-allow," "$T/dead-disjoint.json"
  # The guard's whole reason for existing: an unreadable settings.json makes the
  # jq query return empty, which reads as "no dead rules" — a pass asserted over
  # a file that was never read.
  deadcheck "an unreadable settings.json is skipped, never passed" \
    "REVIEW:dead-allow," "$T/none.json" "is unreadable"

  # --- check_hooks ------------------------------------------------------------
  hookcheck() { # $1 = label, $2 = expected, $3 = SETTINGS, $4 = CFG, $5 = substring
    local got
    got=$( SETTINGS=$3; CFG=$4; probe check_hooks "$RAW" )
    verdict "$1" "$2" "$(detail_has "$got" "${5:-}")"
  }
  reg() { # $1 = settings file, $2... = registered hook basenames
    local f=$1 c sep="" cmds=""; shift
    for c in "$@"; do cmds="$cmds$sep{\"type\":\"command\",\"command\":\"/h/$c\"}"; sep=","; done
    printf '{"hooks":{"PreToolUse":[{"matcher":"*","hooks":[%s]}]}}\n' "$cmds" >"$f"
  }

  mkdir -p "$T/hooks-unreg/hooks" "$T/hooks-orphan/hooks" \
           "$T/hooks-nonexec/hooks" "$T/hooks-empty/hooks" "$T/hooks-ok/hooks"
  for d in hooks-unreg hooks-orphan hooks-nonexec hooks-ok; do
    printf '#!/usr/bin/env bash\n' >"$T/$d/hooks/live.sh"; chmod 755 "$T/$d/hooks/live.sh"
  done
  reg "$T/reg-none.json"
  reg "$T/reg-live.json" live.sh
  reg "$T/reg-live-ghost.json" live.sh ghost.sh
  chmod 644 "$T/hooks-nonexec/hooks/live.sh"

  hookcheck "a hook on disk that nothing registers never fires" \
    "FAIL:hooks," "$T/reg-none.json" "$T/hooks-unreg" "is not registered in settings.json"
  hookcheck "a registered hook with no file errors on every trigger" \
    "FAIL:hooks," "$T/reg-live-ghost.json" "$T/hooks-orphan" "has no file in config/hooks/"
  hookcheck "a registered hook that is not executable fails silently" \
    "FAIL:hooks," "$T/reg-live.json" "$T/hooks-nonexec" "NOT executable"
  # Not hypothetical: CFG kept a stale "$REPO/nix/..." prefix and one run
  # reported all 4 hooks missing while every one was present on disk.
  hookcheck "an empty hooks dir is a CFG problem, not 4 orphaned hooks" \
    "REVIEW:hooks," "$T/reg-live.json" "$T/hooks-empty" "check that CFG points at the live config tree"
  hookcheck "registered and executable passes" \
    "OK:hooks," "$T/reg-live.json" "$T/hooks-ok"

  # --- check_skill_inventory --------------------------------------------------
  invcheck() { # $1 = label, $2 = expected, $3 = REPO, $4 = CFG, $5 = ART_ROOT, $6 = substring
    local got
    got=$( REPO=$3; CFG=$4; ART_ROOT=$5; probe check_skill_inventory "$RAW" )
    verdict "$1" "$2" "$(detail_has "$got" "${6:-}")"
  }

  mkdir -p "$T/inv-cfg/skills/alpha" "$T/inv-cfg/commands" "$T/inv-nongit" "$T/inv-git"
  printf '# alpha\n' >"$T/inv-cfg/skills/alpha/SKILL.md"
  printf '# beta\n'  >"$T/inv-cfg/commands/beta.md"
  git -C "$T/inv-git" init -q >/dev/null 2>&1
  mkdir -p "$T/led-full/skill-reviewer" "$T/led-orphan/skill-reviewer"
  printf '## alpha — 2026-08-12\n\n## beta — 2026-08-13\n' >"$T/led-full/skill-reviewer/LEDGER.md"
  printf '## alpha — 2026-08-12\n\n## gone — 2026-08-13\n' >"$T/led-orphan/skill-reviewer/LEDGER.md"

  invcheck "a REPO that is not a checkout says so, never that units are broken" \
    "REVIEW:skill-inventory,OK:skill-inventory," "$T/inv-nongit" "$T/inv-cfg" "$T/led-full" \
    "is not a git checkout"
  # An untracked unit is invisible to flake eval, so no Skill() rule is generated
  # and it prompts on first use while looking correctly installed.
  #
  # The tracked -> OK path has no fixture: building one needs `git add`, which is
  # denied here, so the only coverage of it is the live run.
  invcheck "every untracked unit is named" \
    "FAIL:skill-inventory,FAIL:skill-inventory," "$T/inv-git" "$T/inv-cfg" "$T/led-full" \
    "is untracked"
  invcheck "an unset ART_ROOT skips the ledger and still reports tracking" \
    "FAIL:skill-inventory,FAIL:skill-inventory,REVIEW:skill-inventory," \
    "$T/inv-git" "$T/inv-cfg" "" "MY_CLAUDE_ARTIFACTS_ROOT is unset"
  invcheck "a ledger row naming no live unit is drift" \
    "REVIEW:skill-inventory,FAIL:skill-inventory,REVIEW:skill-inventory," \
    "$T/inv-nongit" "$T/inv-cfg" "$T/led-orphan" "ledger has a row for 'gone'"

  # --- check_mcp_rules --------------------------------------------------------
  mcpcheck() { # $1 = label, $2 = expected, $3 = SETTINGS, $4 = CLAUDE_JSON, $5 = substring
    local got
    got=$( SETTINGS=$3; CLAUDE_JSON=$4; probe check_mcp_rules "$RAW" )
    verdict "$1" "$2" "$(detail_has "$got" "${5:-}")"
  }

  printf '{"permissions":{"allow":["mcp__ghost__get_x"],"deny":[]}}\n'  >"$T/mcp-ghost.json"
  printf '{"permissions":{"allow":["mcp__asana__get_x"],"deny":[]}}\n'  >"$T/mcp-asana.json"
  printf '{"permissions":{"allow":["mcp__plugin_claude-code-home-manager_expo__build_info"],"deny":[]}}\n' \
    >"$T/mcp-plugin.json"
  printf '{"permissions":{"allow":["Bash(ls *)"],"deny":[]}}\n' >"$T/mcp-norules.json"
  printf '{"mcpServers":{}}\n'                >"$T/cj-empty.json"
  printf '{"mcpServers":{"asana":{}}}\n'      >"$T/cj-user.json"
  printf '{"mcpServers":{"asana":{}},"projects":{"/repo/a":{"mcpServers":{"asana":{}}}}}\n' >"$T/cj-both.json"
  printf '{"mcpServers":{},"projects":{"/repo/a":{"mcpServers":{"asana":{}}}}}\n' >"$T/cj-project.json"

  # The trailing REVIEW is the standing bound on this check — rules are
  # reconciled against declared servers, never against a live tool roster — so it
  # appears in every expectation below.
  mcpcheck "a rule whose server is declared nowhere matches nothing" \
    "FAIL:mcp-rules,REVIEW:mcp-rules," "$T/mcp-ghost.json" "$T/cj-empty.json" \
    "no server named 'ghost'"
  mcpcheck "user scope plus project scope is two registrations of one server" \
    "FAIL:mcp-rules,REVIEW:mcp-rules," "$T/mcp-asana.json" "$T/cj-both.json" \
    "BOTH at user scope"
  # `claude mcp add` defaults to --scope local, so this is the shape a
  # correct-looking command produces: it resolves in one directory and is
  # silently absent everywhere else.
  mcpcheck "a project-only server is surfaced, not passed" \
    "REVIEW:mcp-rules,REVIEW:mcp-rules," "$T/mcp-asana.json" "$T/cj-project.json" \
    "only under projects"
  mcpcheck "a declared server with no rule costs a prompt per call" \
    "REVIEW:mcp-rules,REVIEW:mcp-rules," "$T/mcp-norules.json" "$T/cj-user.json" \
    "every call to it prompts"
  # The conflation this check is built to avoid: a Nix-declared server lives in
  # the plugin's .mcp.json in the store, so checking its rules against
  # ~/.claude.json reports every one of them as a missing server.
  mcpcheck "a plugin-prefixed rule is never reported as a missing server" \
    "REVIEW:mcp-rules,OK:mcp-rules," "$T/mcp-plugin.json" "$T/cj-empty.json"
  mcpcheck "a declared server with a matching rule passes" \
    "REVIEW:mcp-rules,OK:mcp-rules," "$T/mcp-asana.json" "$T/cj-user.json"

  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ] || exit 1
  exit 0
fi

check_symlink
check_dead_allows
check_hooks
check_skill_inventory
check_mcp_rules
exit 0
