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

# Create new window with nvim in main pane (remain-on-exit keeps pane alive)
tmux new-window -n "$WINDOW_NAME" -c "$WORKTREE_PATH"
tmux send-keys -t "$WINDOW_NAME" 'nvim' Enter

# Split horizontally (top/bottom) with shell in bottom pane at 30%
tmux split-window -v -t "$WINDOW_NAME" -c "$WORKTREE_PATH" -l '30%'

# Split the bottom pane vertically (left/right) at 50%
tmux split-window -h -t "$WINDOW_NAME" -c "$WORKTREE_PATH" -l '50%'

# Start claude in the bottom-left pane
tmux send-keys -t "$WINDOW_NAME.2" 'claude' Enter

# Focus the nvim pane (top)
tmux select-pane -t "$WINDOW_NAME.1"
