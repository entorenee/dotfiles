#!/usr/bin/env bash
# notify-attention.sh — Claude Code Notification hook.
#
# Fires a native desktop banner when a session needs attention so you can
# find the right worktree among many concurrent tmux sessions. The banner
# title is the worktree's git branch; the body is a reason tag plus a short
# snippet of what the session is asking.
#
# Cross-platform: terminal-notifier on macOS (falls back to osascript if it
# isn't installed yet), notify-send on Linux. On macOS, clicking the banner
# focuses the originating tmux session/window/pane and raises Ghostty.
# Requires: jq, plus terminal-notifier (macOS) / notify-send + libnotify (Linux).
#
# Registered in nix/modules/claude/default.nix under hooks.Notification with
# matcher "permission_prompt|idle_prompt"; the in-script guard below repeats
# that filter so the script is safe regardless of the matcher config.

set -euo pipefail

payload="$(cat)"

ntype="$(printf '%s' "$payload" | jq -r '.notification_type // empty')"

# Only notify on the two attention-worthy events; ignore the rest
# (auth_success, elicitation_*, etc.).
case "$ntype" in
  permission_prompt) reason="🔐 Needs permission" ;;
  idle_prompt) reason="💬 Waiting for input" ;;
  *) exit 0 ;;
esac

cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
msg="$(printf '%s' "$payload" | jq -r '.message // empty')"
transcript="$(printf '%s' "$payload" | jq -r '.transcript_path // empty')"
sid="$(printf '%s' "$payload" | jq -r '.session_id // empty')"

# tmux context for click-to-focus (macOS / terminal-notifier only). Captured
# here where $TMUX and $TMUX_PANE are set; the click handler runs detached
# without them, so absolute targets and the tmux binary path are baked into
# the command now. Assumes a single attached client (one terminal window,
# switch sessions inside) — switch-client redirects that client.
tmux_focus_cmd=""
if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
  tmux_bin="$(command -v tmux || true)"
  tmux_target="$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null || true)"
  if [ -n "$tmux_bin" ] && [ -n "$tmux_target" ]; then
    tmux_sess="${tmux_target%%:*}"
    tmux_win="${tmux_target%.*}"
    client_tty="$(tmux display-message -p '#{client_tty}' 2>/dev/null || true)"
    # Select the origin window+pane, redirect the attached client to that
    # session, then raise Ghostty. Targets are single-quoted; tmux session and
    # window names carry no shell metacharacters in this setup.
    tmux_focus_cmd="$tmux_bin select-window -t '$tmux_win'; $tmux_bin select-pane -t '$tmux_target';"
    if [ -n "$client_tty" ]; then
      tmux_focus_cmd="$tmux_focus_cmd $tmux_bin switch-client -c '$client_tty' -t '$tmux_sess';"
    else
      tmux_focus_cmd="$tmux_focus_cmd $tmux_bin switch-client -t '$tmux_sess';"
    fi
    tmux_focus_cmd="$tmux_focus_cmd open -a Ghostty"
  fi
fi

# Title: git branch of the worktree, else the directory name.
title=""
if [ -n "$cwd" ]; then
  title="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  [ -z "$title" ] && title="$(basename "$cwd")"
fi
[ -z "$title" ] && title="Claude Code"

# Snippet: the payload message if present, otherwise the last assistant text
# block from the transcript. Falls back to empty (just the reason tag) if
# neither is available.
snippet="$msg"
if [ -z "$snippet" ] && [ -n "$transcript" ] && [ -f "$transcript" ]; then
  snippet="$(tail -n 200 "$transcript" | jq -rs '
      map(select(.type == "assistant"))
      | last
      | .message.content
      | if type == "array"
          then (map(select(.type == "text") | .text) | join(" "))
          else (. // "")
        end
    ' 2>/dev/null || true)"
fi

# Collapse whitespace and truncate for a readable banner.
snippet="$(printf '%s' "$snippet" | tr '\n' ' ' | tr -s ' ' | sed -e 's/^ //' -e 's/ $//')"
if [ "${#snippet}" -gt 100 ]; then
  snippet="${snippet:0:100}…"
fi

body="$reason"
[ -n "$snippet" ] && body="$reason — $snippet"

case "$(uname -s)" in
  Darwin)
    if command -v terminal-notifier >/dev/null 2>&1; then
      # -group replaces any prior banner from the same session, so concurrent
      # sessions each get one updating slot instead of a growing stack.
      args=(-title "$title" -message "$body" -sound Ping)
      [ -n "$sid" ] && args+=(-group "$sid")
      # Clicking the banner jumps the terminal to the originating tmux
      # session/window/pane; otherwise it just raises Ghostty.
      if [ -n "$tmux_focus_cmd" ]; then
        args+=(-execute "$tmux_focus_cmd")
      else
        args+=(-activate com.mitchellh.ghostty)
      fi
      terminal-notifier "${args[@]}" >/dev/null 2>&1 || true
    else
      # Fallback if terminal-notifier isn't installed yet (e.g. pre-rebuild).
      # Escape backslashes and double quotes for the AppleScript string literals.
      esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
      osascript -e "display notification \"$(esc "$body")\" with title \"$(esc "$title")\" sound name \"Ping\"" >/dev/null 2>&1 || true
    fi
    ;;
  Linux)
    if command -v notify-send >/dev/null 2>&1; then
      notify-send -a "Claude Code" "$title" "$body" >/dev/null 2>&1 || true
    fi
    ;;
esac

exit 0
