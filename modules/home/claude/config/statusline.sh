#!/bin/bash
# Two-line statusline with visual context progress bar
#
# Line 1: Model, folder, branch
# Line 2: Progress bar, context, cost, wall/API time, cache hit rate
#
# The context denominator is resolved per session and is not always 200k — it can be
# 1M on some models, or come from CLAUDE_CODE_MAX_CONTEXT_TOKENS. Absolute tokens are
# rendered beside the percentage because a bare percentage is not comparable across
# sessions and disagrees with any tool assuming a fixed window.
#
# cache% is the prompt-cache hit ratio for the last API call, not a context measure.
# api time is accumulated API latency; the clock beside it is wall-clock session time.

# Read stdin (Claude Code passes JSON data via stdin)
stdin_data=$(cat)

# Single jq call - extract all values at once
IFS=$'\t' read -r current_dir model_name cost duration_ms api_duration_ms ctx_used ctx_tokens ctx_window cache_pct < <(
    echo "$stdin_data" | jq -r '[
        .workspace.current_dir // "unknown",
        .model.display_name // "Unknown",
        (try (.cost.total_cost_usd // 0 | . * 100 | floor / 100) catch 0),
        (.cost.total_duration_ms // 0),
        (.cost.total_api_duration_ms // 0),
        (try (
            if (.context_window.remaining_percentage // null) != null then
                100 - (.context_window.remaining_percentage | floor)
            elif (.context_window.context_window_size // 0) > 0 then
                (((.context_window.current_usage.input_tokens // 0) +
                  (.context_window.current_usage.cache_creation_input_tokens // 0) +
                  (.context_window.current_usage.cache_read_input_tokens // 0)) * 100 /
                 .context_window.context_window_size) | floor
            else "null" end
        ) catch "null"),
        (try (
            if (.context_window.total_input_tokens // 0) > 0 then
                .context_window.total_input_tokens
            else
                ((.context_window.current_usage.input_tokens // 0) +
                 (.context_window.current_usage.cache_creation_input_tokens // 0) +
                 (.context_window.current_usage.cache_read_input_tokens // 0))
            end
        ) catch 0),
        (.context_window.context_window_size // 0),
        (try (
            (.context_window.current_usage // {}) |
            if (.input_tokens // 0) + (.cache_read_input_tokens // 0) > 0 then
                ((.cache_read_input_tokens // 0) * 100 /
                 ((.input_tokens // 0) + (.cache_read_input_tokens // 0))) | floor
            else 0 end
        ) catch 0)
    ] | @tsv'
)

# Bash-level fallback: if jq crashed entirely, extract fields individually
if [ -z "$current_dir" ] && [ -z "$model_name" ]; then
    current_dir=$(echo "$stdin_data" | jq -r '.workspace.current_dir // .cwd // "unknown"' 2>/dev/null)
    model_name=$(echo "$stdin_data" | jq -r '.model.display_name // "Unknown"' 2>/dev/null)
    cost=$(echo "$stdin_data" | jq -r '(.cost.total_cost_usd // 0)' 2>/dev/null)
    duration_ms=$(echo "$stdin_data" | jq -r '(.cost.total_duration_ms // 0)' 2>/dev/null)
    api_duration_ms=$(echo "$stdin_data" | jq -r '(.cost.total_api_duration_ms // 0)' 2>/dev/null)
    ctx_used=""
    ctx_tokens="0"
    ctx_window="0"
    cache_pct="0"
    : "${current_dir:=unknown}"
    : "${model_name:=Unknown}"
    : "${cost:=0}"
    : "${duration_ms:=0}"
    : "${api_duration_ms:=0}"
fi

# Compact token counts: 104940 -> 104k, 1000000 -> 1.0M
fmt_tokens() {
    local n="${1:-0}"
    [ "$n" -gt 0 ] 2>/dev/null || { printf '0'; return; }
    if [ "$n" -ge 1000000 ]; then
        printf '%d.%dM' $((n / 1000000)) $(((n % 1000000) / 100000))
    elif [ "$n" -ge 1000 ]; then
        printf '%dk' $((n / 1000))
    else
        printf '%d' "$n"
    fi
}

fmt_duration() {
    local ms="${1:-0}"
    [ "$ms" -gt 0 ] 2>/dev/null || return
    local total_sec=$((ms / 1000))
    local hours=$((total_sec / 3600))
    local minutes=$(((total_sec % 3600) / 60))
    local seconds=$((total_sec % 60))
    if [ "$hours" -gt 0 ]; then
        printf '%dh %dm' "$hours" "$minutes"
    elif [ "$minutes" -gt 0 ]; then
        printf '%dm %ds' "$minutes" "$seconds"
    else
        printf '%ds' "$seconds"
    fi
}

# Git info
if cd "$current_dir" 2>/dev/null; then
    git_branch=$(git -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null)
    git_root=$(git -c core.useBuiltinFSMonitor=false rev-parse --show-toplevel 2>/dev/null)
fi

# Build repo path display (folder name only for brevity)
if [ -n "$git_root" ]; then
    repo_name=$(basename "$git_root")
    if [ "$current_dir" = "$git_root" ]; then
        folder_name="$repo_name"
    else
        folder_name=$(basename "$current_dir")
    fi
else
    folder_name=$(basename "$current_dir")
fi

# Generate visual progress bar for context usage
progress_bar=""
bar_width=12

if [ -n "$ctx_used" ] && [ "$ctx_used" != "null" ]; then
    filled=$((ctx_used * bar_width / 100))
    empty=$((bar_width - filled))

    if [ "$ctx_used" -lt 50 ]; then
        bar_color='\033[32m'  # Green (0-49%)
    elif [ "$ctx_used" -lt 80 ]; then
        bar_color='\033[33m'  # Yellow (50-79%)
    else
        bar_color='\033[31m'  # Red (80-100%)
    fi

    progress_bar="${bar_color}"
    for ((i=0; i<filled; i++)); do
        progress_bar="${progress_bar}█"
    done
    progress_bar="${progress_bar}\033[2m"
    for ((i=0; i<empty; i++)); do
        progress_bar="${progress_bar}⣿"
    done
    progress_bar="${progress_bar}\033[0m"

    # Tokens over the resolved window, so the denominator is never ambiguous
    if [ "$ctx_tokens" -gt 0 ] 2>/dev/null && [ "$ctx_window" -gt 0 ] 2>/dev/null; then
        ctx_pct="$(fmt_tokens "$ctx_tokens")/$(fmt_tokens "$ctx_window") ${ctx_used}%"
    else
        ctx_pct="${ctx_used}%"
    fi
else
    ctx_pct=""
fi

session_time=$(fmt_duration "$duration_ms")
api_time=$(fmt_duration "$api_duration_ms")

# Separator
SEP='\033[2m│\033[0m'

# Get short model name (e.g., "Opus" instead of "Claude 3.5 Opus")
short_model=$(echo "$model_name" | sed -E 's/Claude [0-9.]+ //; s/^Claude //')

# LINE 1: [Model] folder | branch
line1=$(printf '\033[37m[%s]\033[0m' "$short_model")
line1="$line1 $(printf '\033[94m📁 %s\033[0m' "$folder_name")"
if [ -n "$git_branch" ]; then
    line1="$line1 $(printf '%b \033[96m🌿 %s\033[0m' "$SEP" "$git_branch")"
fi

# LINE 2: Progress bar | tokens/window % | cost | wall time · api time | cache %
line2=""
if [ -n "$progress_bar" ]; then
    line2=$(printf '%b' "$progress_bar")
fi
if [ -n "$ctx_pct" ]; then
    if [ -n "$line2" ]; then
        line2="$line2 $(printf '\033[37m%s\033[0m' "$ctx_pct")"
    else
        line2=$(printf '\033[37m%s\033[0m' "$ctx_pct")
    fi
fi
if [ -n "$line2" ]; then
    line2="$line2 $(printf '%b \033[33m$%s\033[0m' "$SEP" "$cost")"
else
    line2=$(printf '\033[33m$%s\033[0m' "$cost")
fi
if [ -n "$session_time" ]; then
    line2="$line2 $(printf '%b \033[36m⏱ %s\033[0m' "$SEP" "$session_time")"
fi
if [ -n "$api_time" ]; then
    line2="$line2 $(printf '\033[2mapi %s\033[0m' "$api_time")"
fi
if [ "$cache_pct" -gt 0 ] 2>/dev/null; then
    line2="$line2 $(printf '%b \033[2mcache %s%%\033[0m' "$SEP" "$cache_pct")"
fi

printf '%b\n\n%b' "$line1" "$line2"
