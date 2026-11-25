# Per-transcript extraction for the beads trial. beads-trial.sh is the caller.
#
#   jq -sR -f beads-trial.jq --arg art "$ART_ROOT" --arg file <path> <path>
#
# Emits one object per main-session transcript: where it ran, when, and the raw
# counts the trial indicators are built from. Arms are NOT decided here — they
# come from arms.tsv in the caller, so a transcript can never vote on its own arm.
#
# ishuman / isscaffold / isinterrupt / iscorrection / textof / toolsof /
# istoolresult are copied verbatim from mine.jq: `jq -f` cannot import from a
# file whose top level is a program. Change them there first, then here, or the
# trial's correction counts stop being comparable with skill-reviewer's.

def parse: split("\n") | map(fromjson? // empty);

def epoch: if . == null then null else (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) end;

# --- copied from mine.jq ----------------------------------------------------

def textof:
  if (.message.content | type) == "string" then .message.content
  elif (.message.content | type) == "array"
  then [.message.content[] | select(.type == "text") | .text] | join("\n")
  else "" end;

def toolsof:
  if (.message.content | type) == "array"
  then [.message.content[] | select(.type == "tool_use")]
  else [] end;

def istoolresult:
  (.message.content | type) == "array"
  and ([.message.content[] | select(.type == "tool_result")] | length) > 0;

def ishuman:
  .type == "user"
  and ((.isMeta // false) | not)
  and ((.isSidechain // false) | not)
  and (istoolresult | not);

def isscaffold:
  . as $t
  | any(
      [ "Base directory for this skill", "Skill base directory:",
        "<local-command-stdout>", "<command-message>", "<task-notification>",
        "<system-reminder>", "<bash-input>", "<bash-stdout>", "<bash-stderr>",
        "Caveat: The messages below were generated",
        "This session is being continued from a previous conversation" ][];
      . as $m | $t | contains($m)
    );

def isinterrupt: startswith("[Request interrupted");

def iscorrection:
  ascii_downcase as $l
  | any(
      [ "actually", "incorrect", "that's wrong", "thats wrong", "not right",
        "you missed", "revert", "undo", "don't", "do not", "no,", "nope",
        "wrong", "isn't", "instead", "why did you", "shouldn't", "should not",
        "didn't", "not what", "re-check", "recheck", "double check",
        "are you sure", "that isn", "stop",
        "drop item", "drop those", "drop the ", "remove item", "ignore item",
        "skip item", "fix item", "fix items", "disregard", "take out" ][];
      . as $m | $l | contains($m)
    );

# --- trial-specific ---------------------------------------------------------

# Every skill invocation on a record, by name: slash command or Skill call.
# Same record shapes as mine.jq's invoked($skill), generalised to any name so
# "the next Skill invocation" can close a pre-pr window.
def invocations:
  if (.isSidechain // false) then []
  elif .type == "user" and ((.message.content | type) == "string") then
    [ .message.content | scan("<command-name>/([^<]+)</command-name>") | .[0] ]
  elif .type == "assistant" then
    [ toolsof[] | select(.name == "Skill") | .input.skill? | strings ]
  else [] end;

# State the trial expects beads to absorb: progress ledgers, plan files, memory.
def isstate:
  endswith("-progress.md")
  or test("/plans/[^/]+\\.md$")
  or test("/\\.claude/projects/[^/]+/memory/");

# Work on the product rather than on the bookkeeping. The first such edit is the
# line a `bd create` has to beat for indicator 2.
def isproduct($art):
  (isstate | not)
  and (($art != "" and startswith($art)) | not)
  and (contains("/.claude/") | not)
  and (test("^(/private)?/tmp/|^/var/folders/") | not);

def edits:
  [ toolsof[] | select(.name == "Edit" or .name == "Write" or .name == "MultiEdit")
    | .input.file_path? | strings ];

# A `bd create` is credited from its OUTPUT, linked back to a command that ran
# bd. Matching output alone counts any session that greps an old transcript.
# The command must have `bd create` in command position — start of a segment,
# after optional env assignments or `rtk` — because a quoted mention
# (`rtk rewrite "bd create x"`, `grep 'bd create'`) is not a run.
def created_ids:
  [ scan("Created issue: ([A-Za-z0-9_.-]+-[A-Za-z0-9.]+)") | .[0] ];

def isbdcreate:
  test("(^|[;&|(])\\s*([A-Za-z_][A-Za-z0-9_]*=\\S*\\s+)*(rtk\\s+)?bd\\s+create(\\s|$)");

# ---------------------------------------------------------------------------

parse
| map(select(.type == "user" or .type == "assistant")) as $recs
| if ($recs | length) == 0 then empty
  elif any($recs[]; .isSidechain // false) and all($recs[]; .isSidechain // false) then empty
  else

  # Tool-call commands by id, so a tool_result can be traced to what produced it.
  ( [ $recs[] | select(.type == "assistant") | toolsof[]
      | select(.name == "Bash") | {key: .id, value: (.input.command // "")} ]
    | from_entries ) as $cmds

  | [ $recs | to_entries[] | .key as $i | .value
      | { i: $i,
          ts: (.timestamp | epoch),
          branch: .gitBranch,
          cwd: .cwd,
          human: (ishuman and (textof | length > 0)
                  and (textof | isscaffold | not) and (textof | isinterrupt | not)),
          correction: (textof | iscorrection),
          inv: invocations,
          edits: edits,
          # Claude-run: a tool_result whose tool_use was a bd create.
          # User-run (`! bd create`): <bash-stdout> following a <bash-input> of one.
          created: (
            if istoolresult then
              [ .message.content[] | select(.type == "tool_result")
                | select(($cmds[.tool_use_id] // "") | isbdcreate)
                | (if (.content | type) == "string" then .content
                   else [.content[]? | .text? // empty] | join("\n") end)
                | created_ids[] ]
            elif .type == "user" and ((.message.content | type) == "string")
                 and (.message.content | contains("<bash-stdout>")) then
              ( $i as $j
                | [ range($j - 1; -1; -1) as $k | $recs[$k]
                    | select(.type == "user" and ((.message.content | type) == "string")
                             and (.message.content | contains("<bash-input>"))) ]
                | first? // null ) as $in
              | if $in != null and ($in.message.content | isbdcreate)
                then .message.content | created_ids else [] end
            else [] end ) }
    ] as $t

  # Corrections inside a pre-pr window: from the pre-pr invocation until the
  # next unrelated skill invocation, or session end. pre-pr calls its hygiene
  # skills itself before the user says a word, so closing on those left most
  # windows empty: measured 2026-11-18, 16 of ~26 runs closed at pre-pr's own
  # fw-code-hygiene/code-hygiene call. Built-in commands are not skills either.
  | [ "code-hygiene", "fw-code-hygiene", "comment-review",
      "compact", "clear", "context", "cost", "model", "config", "status",
      "help", "memory", "mcp", "permissions", "plugin", "rename", "resume" ] as $through
  | ( reduce $t[] as $r ({open: false, n: 0};
        ([ $r.inv[] | select(. as $s | $through | index($s) | not) ]) as $real
        | if ($real | length) > 0 then .open = ($real[-1] == "pre-pr")
        elif .open and $r.human and $r.correction then .n += 1
        else . end)
      | .n ) as $prepr_corr

  # The session belongs to the branch it ends on: scoping happens on the
  # default branch, then the session moves into the new worktree with /cd, so
  # the first branch seen is the wrong one. Detached HEAD reports as "HEAD";
  # neither it nor a missing branch can be assigned to an arm, so a session
  # with no other branch goes to unattributed.
  | ([ $t[] | select(.branch != null and .branch != "" and .branch != "HEAD") | .branch ]
     | last? // null) as $branch
  # Where the session joined that branch. Its arms row is dated the day the
  # worktree was created, which can be after the session started.
  | ([ $t[] | select($branch != null and .branch == $branch) ] | first? // null) as $entered
  | ($entered.cwd // ([ $t[] | select(.cwd != null) | .cwd ] | first? // null)) as $cwd
  | ([ $t[] | .inv[] ]) as $allinv

  | { file: $file,
      session: ([ $recs[] | .sessionId | strings ] | first? // null),
      cwd: $cwd,
      branch: $branch,
      start: ([ $t[] | .ts | numbers ] | min),
      branch_ts: $entered.ts,
      state_edits: ([ $t[] | .edits[] | select(isstate) ] | length),
      handoff_runs: ([ $allinv[] | select(. == "handoff") ] | length),
      reflect_runs: ([ $allinv[] | select(. == "reflect") ] | length),
      prepr_runs: ([ $allinv[] | select(. == "pre-pr") ] | length),
      corrections: ([ $t[] | select(.human and .correction) ] | length),
      prepr_corrections: $prepr_corr,
      first_create_ts: ([ $t[] | select(.created | length > 0) | .ts ] | min),
      first_product_edit_ts: ([ $t[] | select(any(.edits[]; isproduct($art))) | .ts ] | min),
      created_ids: ([ $t[] | .created[] ] | unique) }
  end
