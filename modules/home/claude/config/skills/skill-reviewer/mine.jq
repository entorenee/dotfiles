# Extract gate evidence for one skill from Claude Code transcripts.
#
#   jq -sR -f mine.jq --arg skill investigate <transcript>.jsonl
#
# Input is the whole file as one raw string (-sR) and the filter parses lines
# itself, so a single malformed line cannot abort a run over 300 transcripts.
#
# Output is one JSON object per transcript. Emits nothing when the skill was
# never invoked in that file, so the caller can glob the whole projects
# directory and let the filter do the selection.

def parse: split("\n") | map(fromjson? // empty);

def epoch: if . == null then null else (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) end;

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

# A real human turn. Everything excluded here has impersonated one at some
# point: isMeta covers system injections, isSidechain covers subagent turns,
# and tool_result arrays carry the user role but were never typed by anyone.
def ishuman:
  .type == "user"
  and ((.isMeta // false) | not)
  and ((.isSidechain // false) | not)
  and (istoolresult | not);

# Skill payloads and command scaffolding also arrive as user text. These
# markers are what distinguishes them from something the human actually wrote.
def isscaffold:
  . as $t
  | any(
      [ "Base directory for this skill", "Skill base directory:",
        "<local-command-stdout>", "<command-message>", "<task-notification>",
        "<system-reminder>", "<bash-input>", "<bash-stdout>", "<bash-stderr>",
        "Caveat: The messages below were generated",
        # Compaction summaries carry the user role but nobody typed them, and
        # they quote enough of the session to trip every correction keyword.
        "This session is being continued from a previous conversation" ][];
      . as $m | $t | contains($m)
    );

# An interruption is the strongest gate signal there is — the human stopped the
# run mid-flight — but it carries no prose, so it is counted separately rather
# than averaged into the review-time figures.
def isinterrupt: startswith("[Request interrupted");

# The signal this whole loop runs on: a human turn that pushes back. Cheap
# keyword matching, deliberately over-inclusive — a reviewer reads the hits and
# discards the false positives, which is far less costly than missing a catch.
#
# The second group catches rejection by imperative. A skill that reports a
# numbered list gets corrected as "drop items 3 and 4", which carries none of
# the words above: measured 2026-08-17, pr-review scored 0 corrections across
# 8 runs while at least 2 of its 7 gate turns rejected findings outright.
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

# Pinned to the record shape a real invocation produces: a session that analyses
# skill usage writes the invocation strings into its own transcript, so matching
# on text alone makes the review count itself as a run.
#
# Sidechains are excluded because a subagent carries no human: it contributes
# gates=0 and drags every rate toward zero. Measured 2026-08-18, 3 of
# evidence-analysis-core's 4 "sessions" were subagent transcripts, turning one
# real run into an apparent four. Such records sit only in agent-*.jsonl files
# (114 of 114), so those files now emit nothing at all and there is no per-file
# sidechain count worth returning — inventory.sh's SUB column is where composed
# use stays visible.
def invoked($skill):
  ((.isSidechain // false) | not)
  and (
    # Slash command: a user record whose content is the plain string form.
    ( .type == "user"
      and ((.message.content | type) == "string")
      and (.message.content | contains("<command-name>/" + $skill + "</command-name>")) )
    # Skill call: a tool_use, which only ever sits on an assistant record.
    or ( .type == "assistant"
         and any(toolsof[]; .name == "Skill" and (.input.skill? == $skill)) )
  );

# ---------------------------------------------------------------------------

parse
| [ .[]
    | select(.type == "user" or .type == "assistant")
    | { ts: (.timestamp | epoch),
        role: (if .type == "assistant" then "assistant" else "user" end),
        human: ishuman,
        text: textof,
        inv: invoked($skill) }
  ]
| . as $turns
| ([ $turns | to_entries[] | select(.value.inv) | .key ]) as $invIdx
| if ($invIdx | length) == 0 then empty else

  # Everything from the first invocation onward is in-scope for the gate.
  ($invIdx[0]) as $start
  | [ range($start; $turns | length) ] as $scope

  # A human turn's review time is the wall clock from the assistant message it
  # answers. That is an upper bound on attention (it counts walk-aways) and a
  # lower bound on total effort (it misses review done outside the session).
  # Gaps over 60 min are dropped as walk-aways rather than averaged in.
  | [ $scope[]
      | . as $i
      | $turns[$i]
      | select(.human and (.text | length > 0) and (.text | isscaffold | not))
      | { i: $i,
          ts: .ts,
          interrupt: (.text | isinterrupt),
          correction: (.text | iscorrection),
          chars: (.text | length),
          gap_min: (
            [ range(0; $i) | select($turns[.].role == "assistant") ] as $prev
            | if ($prev | length) == 0 then null
              else ( ($turns[$i].ts - $turns[$prev[-1]].ts) / 6 | round / 10 ) end
          ),
          text: (.text | .[0:1200]),
          # For an interruption the human's own text is empty, so the evidence
          # is what the run was saying when it got stopped.
          stopped: (
            if (.text | isinterrupt) then
              ( [ range(0; $i) | select($turns[.].role == "assistant"
                                        and ($turns[.].text | length > 0)) ] as $prev
                | if ($prev | length) == 0 then null
                  else ($turns[$prev[-1]].text | .[0:600]) end )
            else null end
          ) }
    ] as $all
  | [ $all[] | select(.interrupt | not) ] as $gates

  | { skill: $skill,
      invocations: ($invIdx | length),
      first_invoked: ($turns[$start].ts | todateiso8601),
      gate_turns: ($gates | length),
      interruptions: ([ $all[] | select(.interrupt) ] | length),
      corrections: ([ $gates[] | select(.correction) ] | length),
      review_minutes: ([ $gates[] | .gap_min | select(. != null and . > 0 and . < 60) ] | add // 0),
      median_gap_min: (
        [ $gates[] | .gap_min | select(. != null and . > 0 and . < 60) ] | sort
        | if length == 0 then null else .[(length / 2 | floor)] end
      ),
      gates: $gates,
      interrupts: [ $all[] | select(.interrupt) | {ts, gap_min, stopped} ] }
  end
