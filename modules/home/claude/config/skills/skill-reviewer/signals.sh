#!/usr/bin/env bash
#
# Structural friction signals across the transcript archive.
#
#   bash signals.sh              human table + aggregate + coverage footer
#   bash signals.sh --json       one JSON record per session
#   bash signals.sh --denials    denials grouped by command shape
#   bash signals.sh --verify     re-derive the aggregate independently and diff
#   bash signals.sh --rollup     append a counts-only row to the friction repo
#
# Why a scanner and not a hook: every signal below is ALREADY recorded, so a
# hook would re-write data that exists, add a moving part that can silently stop
# firing, and produce nothing retroactive. A scanner is re-derivable from source,
# which is the only reason its numbers can be checked at all.
#
# Every count here is a FLOOR. A wrong proposal corrected purely in prose — no
# edit, no rejected call — is invisible to every structural arm. See the footer.

set -uo pipefail

MODE=table
case "${1:-}" in
  --json)    MODE=json ;;
  --denials) MODE=denials ;;
  --verify)  MODE=verify ;;
  --rollup)  MODE=rollup ;;
  "")        MODE=table ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac

TRANSCRIPTS="${SKILL_TRANSCRIPT_DIR:-$HOME/.claude/projects}"
HERE="$(cd "$(dirname "$0")" && pwd)"
FILTER="$HERE/signals.jq"
[ -f "$FILTER" ] || { echo "missing signals.jq beside $0" >&2; exit 2; }

WORK="${TMPDIR:-/tmp}/skill-signals"
mkdir -p "$WORK"
ROWS="$WORK/rows.json"

# Top-level transcripts only. A subagent sidechain has no human at the gate, so
# it can carry no correction signal; `isSidechain` filtering inside the jq is
# belt-and-braces for resumed sessions that inline one.
find "$TRANSCRIPTS" -name '*.jsonl' -not -path '*/subagents/*' -print0 2>/dev/null \
  | xargs -0 -I{} sh -c 'jq -s -f "$0" "$1" 2>/dev/null' "$FILTER" {} \
  | jq -s 'map(select(.typed > 0))' > "$ROWS"

N=$(jq 'length' "$ROWS")
if [ "$N" -eq 0 ]; then
  echo "No sessions with human turns found under $TRANSCRIPTS" >&2
  exit 1
fi

agg() { jq -r "$1" "$ROWS"; }

TYPED=$(agg '[.[].typed]|add')
INTR=$(agg '[.[].interrupts]|add')
D_RULE=$(agg '[.[].denials.rule]|add')
D_USER=$(agg '[.[].denials.user]|add')
D_AUTO=$(agg '[.[].denials.automode]|add')
LEX=$(agg '[.[].lexical]|add')
CH3=$(agg '[.[]|select(.max_chain>=3)]|length')
CHMAX=$(agg '[.[].max_chain]|max')

# Eligible sessions: >= 3 typed turns.
#
# A depth-3 chain needs three human turns to exist, so a session with fewer
# CANNOT score one — it is not a negative observation, it is not an observation.
# Half the archive (85 of 169 at first run) is in that class, and counting it in
# the denominator only dilutes: the all-sessions rate reads 14% where the rate
# among sessions that could qualify is 29%.
#
# Rate rises monotonically with length (0% / 8% / 36% / 53% / 75% across the
# buckets below), so any before/after comparison must ALSO be checked within a
# bucket. An intervention that changes typical session length moves the headline
# on its own — and the assumptions-at-proposal-time rule plausibly does exactly
# that, by trading wrong work for more clarifying turns.
ELIG=$(agg '[.[]|select(.typed>=3)]|length')
DEEP=$(agg '[.[]|select(.typed>=3 and .max_chain>=3)]|length')
RATE=$(agg '([.[]|select(.typed>=3)]|length) as $e | if $e==0 then 0 else (([.[]|select(.typed>=3 and .max_chain>=3)]|length)*100/$e|round) end')

buckets() {
  jq -r 'map(. + {b: (if .typed<=2 then "1-2" elif .typed<=5 then "3-5"
                      elif .typed<=10 then "6-10" elif .typed<=20 then "11-20"
                      else "21+" end)})
         | group_by(.typed<=2, .typed<=5, .typed<=10, .typed<=20)
         | map({b:.[0].b, n:length, deep:(map(select(.max_chain>=3))|length)})
         | map(. + {pct: (if .n==0 then 0 else (.deep*100/.n|round) end)})
         | reverse | .[] | "\(.b)\t\(.n)\t\(.deep)\t\(.pct)%"' "$ROWS"
}

case "$MODE" in
  json) cat "$ROWS" ;;

  denials)
    # Denials paired with the command that drew them. `toolDenialKind` is
    # structural; permission-audit's text-matching misses 21 of 57 rule denials.
    #
    # Sidechains are INCLUDED here, unlike the session table. A subagent blocked
    # by a permission rule has no human at the gate — so it is not a friction
    # signal — but it is still a rule that needs fixing, which is what this mode
    # is for. 8 of 57 rule denials are sidechain-only and would be invisible
    # otherwise.
    find "$TRANSCRIPTS" -name '*.jsonl' -print0 2>/dev/null \
      | xargs -0 cat 2>/dev/null \
      | jq -rs '
          map(select(.type=="user" and .toolDenialKind != null))
          | map({kind: .toolDenialKind,
                 shape: ((.message.content // [])
                         | if type=="array" then
                             (map(select(.type=="tool_result")
                              | (.content | if type=="array" then (map(.text//"")|join(" ")) else (.//"") end))
                              | join(" "))
                           else "" end
                         | gsub("\\s+"; " ") | .[0:60])})
          | map(. + {src: (if .kind != "permission-rule" then .kind
                           elif (.shape | test("^\\s*Permission to use ")) then "allowlist-gap"
                           elif (.shape | test("was blocked\\.|For security, Claude Code may only")) then "sandbox-deny"
                           else "hook-deny" end)})
          | group_by(.src)[]
          | "\(.[0].src)  (\(length))",
            (group_by(.shape) | sort_by(-length) | .[0:8][] | "    \(length)x  \(.[0].shape)")'
    cat <<'EOF'

# allowlist-gap  candidate for a narrow permissions.allow rule. Check it against
#                permissions.deny first — deny wins, so a contradictory allow is
#                dead weight on arrival.
# hook-deny      a PreToolUse hook refused it (exec-form-guard, pnpm-guard). The
#                command violates a documented rule. NEVER allowlist these — the
#                denial is the intervention, and it demonstrably works.
# sandbox-deny   the sandbox filesystem/network boundary refused it. No allow
#                rule can bypass a sandbox deny; changing it means editing
#                sandbox.filesystem.* — a deliberate hardening decision, not a
#                convenience fix.
# user-rejected  you turned it down. Not a permission problem; read the next
#                command in that session to see what satisfied you instead.
EOF
    ;;

  verify)
    # Re-derive the aggregate with an independent one-liner over the same files,
    # AT THE SAME MOMENT. A hardcoded expected value would be wrong: the archive
    # is live and append-only — `user-rejected` read 33 and then 34 within one
    # session, because a rejection landed while it was being measured.
    IND=$(find "$TRANSCRIPTS" -name '*.jsonl' -not -path '*/subagents/*' -print0 2>/dev/null \
      | xargs -0 cat 2>/dev/null \
      | jq -rs '[.[]|select(.type=="user" and .isSidechain != true)] as $u
                | "\($u|map(select(.promptSource=="typed"))|length) \($u|map(select(.interruptedMessageId!=null))|length) \($u|map(select(.toolDenialKind=="permission-rule"))|length) \($u|map(select(.toolDenialKind=="user-rejected"))|length)"')
    set -- $IND
    ok=0
    printf '%-14s %10s %10s   %s\n' FIELD SCANNER INDEPENDENT RESULT
    check() {
      if [ "$2" = "$3" ]; then printf '%-14s %10s %10s   ok\n' "$1" "$2" "$3"
      else printf '%-14s %10s %10s   MISMATCH\n' "$1" "$2" "$3"; ok=1; fi
    }
    check typed      "$TYPED"  "$1"
    check interrupts "$INTR"   "$2"
    check rule       "$D_RULE" "$3"
    check user-rej   "$D_USER" "$4"
    echo
    [ "$ok" -eq 0 ] && echo "PASS — scanner agrees with independent derivation" \
                    || echo "FAIL — scanner disagrees; do not trust its output"
    exit "$ok"
    ;;

  rollup)
    ROOT="${MY_CLAUDE_FRICTION_ROOT:?unset — run 'make rebuild', then start a new session}"
    [ -d "$ROOT/.git" ] || { echo "not a git repo: $ROOT" >&2; exit 1; }
    mkdir -p "$ROOT/rollups"
    STAMP=$(agg '[.[].date]|max')
    OUT="$ROOT/rollups/${STAMP:0:7}-$(hostname -s).md"
    [ -f "$OUT" ] || {
      echo "# Signal rollup — ${STAMP:0:7} — $(hostname -s)"
      echo
      echo "Counts only; no transcript content. Re-derivable with \`signals.sh\`"
      echo "for as long as the transcripts live (\`cleanupPeriodDays\`)."
      echo
      echo "\`eligible\` = sessions with >= 3 typed turns; \`deep\` = of those, how many"
      echo "reached a rework chain of depth >= 3. **Score movement on deep/eligible**,"
      echo "not on deep/sessions: a depth-3 chain cannot occur in a shorter session, so"
      echo "including those only measures how many short sessions the month happened to"
      echo "contain. Rate also rises with session length, so compare within a bucket too."
      echo
      echo "| through | sessions | eligible | deep | rate | typed | interrupts | rule | user-rej | automode | max chain | lexical |"
      echo "|---|---|---|---|---|---|---|---|---|---|---|---|"
    } > "$OUT"
    printf '| %s | %s | %s | %s | %s%% | %s | %s | %s | %s | %s | %s | %s |\n' \
      "$STAMP" "$N" "$ELIG" "$DEEP" "$RATE" "$TYPED" "$INTR" "$D_RULE" "$D_USER" "$D_AUTO" "$CHMAX" "$LEX" >> "$OUT"
    echo "$OUT"
    echo "git-sync commits and pushes this within ~300s. Do not run git here."
    ;;

  table)
    echo "# transcripts : $TRANSCRIPTS"
    echo "# sessions    : $N with at least one human turn"
    echo
    {
      printf 'DATE\tPROJECT\tBRANCH\tMODE\tTYPED\tINTR\tRULE\tUSER\tAUTO\tCHAIN\tLEX\n'
      jq -r '.[]|select(.interrupts>0 or .denials.rule>0 or .denials.user>0 or .max_chain>=3)
             | [.date, (.project//"-"), (.branch//"-"|.[0:24]), (.mode//"-"),
                .typed, .interrupts, .denials.rule, .denials.user,
                .denials.automode, .max_chain, .lexical] | @tsv' "$ROWS" \
        | sort -r
    } | column -t -s "$(printf '\t')"
    echo
    echo "# Rows shown: sessions with an interruption, a denial, or a chain >= 3."
    echo "# Quiet sessions are counted in the totals below but not listed."
    echo
    printf '# TOTALS  typed=%s  interrupts=%s  rule=%s  user-rejected=%s  automode=%s\n' \
      "$TYPED" "$INTR" "$D_RULE" "$D_USER" "$D_AUTO"
    printf '#         chains>=3=%s (all sessions)  max_chain=%s  lexical=%s\n' "$CH3" "$CHMAX" "$LEX"
    echo
    printf '# HEADLINE  %s/%s eligible sessions have a chain >= 3  (%s%%)\n' "$DEEP" "$ELIG" "$RATE"
    echo   '#           Eligible = >= 3 typed turns. Score movement on THIS, not on'
    echo   '#           the all-sessions figure, and check the buckets below too.'
    echo
    {
      printf 'TURNS\tSESSIONS\tCHAIN>=3\tRATE\n'
      buckets
    } | column -t -s "$(printf '\t')" | sed 's/^/#   /'
    cat <<'EOF'

# COLUMNS
#   TYPED  human-typed turns (promptSource=="typed"). The denominator. Every
#          other `type=="user"` record is a tool result, a skill injection, a
#          slash-command expansion or a compaction summary.
#   INTR   interruptedMessageId != null. The strongest single signal, and the
#          cheapest to miss, because it carries no text.
#   RULE   toolDenialKind=="permission-rule" — blocked by allow/deny matching.
#   USER   toolDenialKind=="user-rejected" — you turned the call down.
#   AUTO   toolDenialKind=="automode-blocked". Auto mode's only visible output;
#          what it ALLOWS is unrecorded, so this is not a measure of its reach.
#   CHAIN  deepest rework chain: consecutive human turns where the assistant
#          went back and re-edited a file it had already edited in that run, or
#          had a call rejected between turns. >= 3 is the confidently-wrong case.
#   LEX    HYPOTHESIS ONLY — wording match on typed turns. Never threshold it.
#          Unfiltered the same regex matches 16% of user records; the filter is
#          what makes it 5%. It is here to be looked at, not counted on.

# COVERAGE — what this cannot see
#   * A wrong proposal corrected purely in prose — no edit, no rejected call —
#     scores nothing. The structural arms are blind to it by construction.
#   * Prompts you APPROVED leave no trace whatsoever. Denials are recorded;
#     approvals are not. No claim about prompt volume can be made from this.
#   * Sessions predating the archive, or older than `cleanupPeriodDays`.
#   * Every number is therefore a FLOOR, never a measurement of the whole.
EOF
    ;;
esac
