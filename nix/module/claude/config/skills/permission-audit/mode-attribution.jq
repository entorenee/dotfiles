# Tag every tool call with the permission mode in effect when it ran.
#
# Input:  slurped array (`jq -s`) of concatenated transcript entries from
#         ~/.claude/projects/*/*.jsonl (and subagent subdirectories).
# Output: flat array of {mode, name, cmd, session, cwd, ts, agent}.
#
# Why a committed file: Claude Code does not record a permission decision per
# tool call. It records `permissionMode` on user-turn entries and emits a
# dedicated `permission-mode` entry on every mode switch. Neither is attached
# to the tool calls themselves, so the mode has to be carried forward through
# each session in timestamp order. That reduce is easy to get subtly wrong
# (silent misattribution, not an error), so it lives here rather than being
# retyped each run.
#
# Grouping is by sessionId rather than by file so concatenating every
# transcript at once is safe — file boundaries do not matter, and subagent
# sidechains keep their own sessionId.

group_by(.sessionId)
| map(
    sort_by(.timestamp)
    | reduce .[] as $e ({mode: "default", out: []};
        # A mode switch may arrive either as a dedicated `permission-mode`
        # entry or stamped on a user turn; both carry `.permissionMode`.
        (if $e.permissionMode != null then .mode = $e.permissionMode else . end)
        | . as $st
        | if $e.type == "assistant" then
            .out += [
              ($e.message.content // [])
              | (if type == "array" then .[] else empty end)
              | select(.type == "tool_use")
              | {
                  mode: $st.mode,
                  name: .name,
                  cmd: (.input.command // ""),
                  session: ($e.sessionId // ""),
                  cwd: ($e.cwd // ""),
                  ts: ($e.timestamp // ""),
                  agent: ($e.agentId // ""),
                }
            ]
          else . end
      )
    | .out
  )
| flatten
