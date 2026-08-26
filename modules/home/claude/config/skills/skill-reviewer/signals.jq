# signals.jq — structural friction signals for one transcript file.
#
# Input:  jq -s over one session transcript (an array of records).
# Output: one JSON object per sessionId found in that file.
#
# Every arm here reads a labelled field. Nothing is inferred from wording except
# the `lexical` count, which is reported separately and never feeds a threshold —
# unfiltered, `\bstill\b` matches 16% of `type=="user"` records, because only 815
# of 17011 of them are human. Filtered to promptSource=="typed" it is 5%.

# Human-typed turns only. `type=="user"` also covers tool results, skill
# injections, slash-command expansions and compaction summaries.
def is_typed: .type == "user" and .promptSource == "typed";

# Text of a message, whether content is a string or a content-block array.
def msg_text:
  (.message.content // "")
  | if type == "array" then (map(select(.type == "text") | .text // "") | join(" "))
    else (. // "") end;

# Files an assistant record edited. Write/Edit/NotebookEdit only — a Read or a
# Bash call is not rework.
def edited_files:
  (.message.content // [])
  | if type == "array" then
      map(select(.type == "tool_use"
                 and (.name == "Edit" or .name == "Write" or .name == "MultiEdit"
                      or .name == "NotebookEdit"))
          | .input.file_path // .input.notebook_path // empty)
    else [] end;

# Ordered event stream for one session: typed turns, rejections, and edits.
def events:
  map(select(.timestamp != null))
  | sort_by(.timestamp)
  | map(
      if is_typed then {k: "T"}
      elif .type == "user" and .toolDenialKind == "user-rejected" then {k: "R"}
      elif .type == "assistant" then
        (edited_files) as $f
        | if ($f | length) > 0 then {k: "E", f: $f} else empty end
      else empty end
    );

# Rework chains.
#
# A chain is a maximal run of typed turns where, between consecutive turns, the
# assistant edited a file it had ALREADY edited earlier in that same run — i.e.
# it went back and changed its own work after being spoken to. Depth = number of
# turns in the run.
#
# A `user-rejected` tool call between two typed turns also continues a chain.
# That covers proposal-shaped sessions, which produce no edits at all: the
# rejection IS the pushback. Without this arm a conversation that argues about
# an approach and never touches a file scores 1, which is the wrong answer.
#
# Depth >= 3 is the "confidently wrong until pushed back on several times" case.
def chains:
  events as $e
  | reduce $e[] as $ev (
      {cur: 0, files: [], gap: [], rej: false, out: []};
      if $ev.k == "T" then
        if .cur == 0 then
          .cur = 1 | .files = [] | .gap = [] | .rej = false
        else
          # Rework = a file in this gap that the chain has already touched.
          (([.gap[]] - ([.gap[]] - [.files[]])) | length > 0) as $rework
          | if ($rework or .rej)
            then .cur += 1 | .files = (.files + .gap | unique)
            else .out += [.cur] | .cur = 1 | .files = (.gap | unique)
            end
          | .gap = [] | .rej = false
        end
      elif $ev.k == "E" then .gap = (.gap + $ev.f)
      elif $ev.k == "R" then .rej = true
      else . end
    )
  | .out + (if .cur > 0 then [.cur] else [] end);

# Denial provenance. A `permission-rule` denial has two sources that call for
# OPPOSITE responses, and conflating them is permission-audit's named failure
# mode — it converts a behavioural problem into permanently loosened permissions.
#
#   allowlist — the engine matched no allow rule. Text begins "Permission to
#               use <Tool> with command …". A narrow allow rule may be correct.
#   hook      — a PreToolUse hook returned deny (exec-form-guard, pnpm-guard).
#               The command violates a documented rule. NEVER allowlist these;
#               the denial IS the intervention, and it works: exec-form-guard
#               cut its target violation rate from 2.95% to 0.25%.
def denial_source:
  ((.message.content // [])
   | if type == "array" then
       (map(select(.type == "tool_result")
        | (.content | if type == "array" then (map(.text // "") | join(" ")) else (. // "") end))
        | join(" "))
     else "" end) as $t
  | if ($t | test("^\\s*Permission to use ")) then "allowlist" else "hook" end;

group_by(.sessionId // .session_id // "unknown")
| map(
    select((.[0].sessionId // .[0].session_id) != null)
    | . as $s
    | ($s | map(select(.isSidechain != true))) as $main
    | ($main | map(select(is_typed))) as $typed
    | {
        session:    ($s[0].sessionId // $s[0].session_id),
        date:       ([$s[] | .timestamp // empty] | sort | (.[0] // "")[0:10]),
        # First cwd, not last: the session's anchor. Taking `last` reports
        # whichever directory a Bash call happened to cd into.
        project:    ([$s[] | .cwd // empty] | first // "" | split("/") | last),
        branch:     ([$s[] | .gitBranch // empty] | last // ""),
        mode:       ([$main[] | .permissionMode // empty] | last // ""),
        typed:      ($typed | length),
        interrupts: ($main | map(select(.interruptedMessageId != null)) | length),
        denials: {
          rule:         ($main | map(select(.toolDenialKind == "permission-rule"))       | length),
          rule_allow:   ($main | map(select(.toolDenialKind == "permission-rule" and (denial_source == "allowlist"))) | length),
          rule_hook:    ($main | map(select(.toolDenialKind == "permission-rule" and (denial_source == "hook")))      | length),
          user:         ($main | map(select(.toolDenialKind == "user-rejected"))         | length),
          automode:     ($main | map(select(.toolDenialKind == "automode-blocked"))      | length),
          unavailable:  ($main | map(select(.toolDenialKind == "automode-unavailable"))  | length)
        },
        # Hypothesis arm. Reported, never thresholded.
        lexical:    ($typed | map(select(msg_text | test("\\bstill\\b|\\bagain\\b|as I said|like I said|I already|^\\s*(no|nope|not quite|that's not)\\b"; "i"))) | length),
        chains:     ($main | chains),
        max_chain:  ($main | chains | max // 0)
      }
  )
| .[]
