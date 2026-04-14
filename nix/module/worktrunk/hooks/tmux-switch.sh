#\!/usr/bin/env bash
# Worktrunk post-switch hook: create/switch tmux windows for worktrees
# Called with: tmux-switch.sh <window-name> <worktree-path>

# Only run inside tmux
[ -z "$TMUX" ] && exit 0

WINDOW_NAME="$1"
WORKTREE_PATH="$2"

if [ -z "$WINDOW_NAME" ] || [ -z "$WORKTREE_PATH" ]; then
  exit 1
fi

# If window already exists, just select it
if tmux list-windows -F '#W' | grep -qx "$WINDOW_NAME"; then
  tmux select-window -t "$WINDOW_NAME"
  exit 0
fi

# Create new window with nvim in main pane
tmux new-window -n "$WINDOW_NAME" -c "$WORKTREE_PATH" "nvim"

# Split horizontally (top/bottom) with shell in bottom pane at 30%
tmux split-window -v -t "$WINDOW_NAME" -c "$WORKTREE_PATH" -l '30%'

# Focus the nvim pane (top)
tmux select-pane -t "$WINDOW_NAME.0"
