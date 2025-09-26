#!/usr/bin/env bash

# Generates AI summaries of jj branch changes for starship prompt
# Uses caching and background processing to minimize prompt latency

set -euo pipefail

# Default model if none provided
DEFAULT_MODEL="sonnet"

# Get model from env var, first argument, or use default
MODEL="${JJ_AI_BRANCH_SUMMARY_MODEL:-${1:-$DEFAULT_MODEL}}"

# Configuration
CACHE_DIR="$HOME/.cache/jj-ai-branch-summary"
CACHE_TIMEOUT_SECS=$(( 60 * 60 * 24 * 7 ))
AI_TIMEOUT_SECS=30
FAILURE_CACHE_TIMEOUT_SECS=$(( 60 * 60 ))  # 1 hour

# Function to detect model type and get appropriate command
get_ai_command() {
    local model="$1"

    # Claude model detection (short aliases only)
    if [[ "$model" == "sonnet" ]] || [[ "$model" == "opus" ]] || [[ "$model" == "haiku" ]]; then
        echo "claude --model $model -p"
        return 0
    fi

    # Ollama model detection - check if model exists
    if command -v ollama >/dev/null 2>&1 && ollama show "$model" >/dev/null 2>&1; then
        echo "ollama run --hidethinking $model"
        return 0
    fi

    # Unsupported model
    echo "Error: Unsupported model '$model'. Use Claude aliases (sonnet, opus, haiku) or install model with 'ollama pull $model'" >&2
    return 1
}

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Function to get log content for hashing
get_log_content() {
    # Check if we're in a jj repo
    if ! jj root >/dev/null 2>&1; then
        exit 0
    fi

    # Get the log content - exit gracefully if no commits ahead of trunk
    local log_content
    log_content=$(jj log -r 'trunk()..@' --no-graph -T 'description.first_line() ++ "\n"' --reversed 2>/dev/null || true)

    # If no commits ahead of trunk, exit silently
    if [[ -z "$log_content" ]]; then
        exit 0
    fi

    echo "$log_content"
}

# Function to generate cache key
generate_cache_key() {
    local log_content="$1"
    local model="$2"
    local content_hash
    content_hash=$(echo -n "$log_content" | sha256sum | cut -d' ' -f1)
    echo "${model}-${content_hash}"
}

# Function to check if cache is fresh
is_cache_fresh() {
    local cache_file="$1"
    if [[ -f "$cache_file" ]]; then
        local cache_age=$(( $(date +%s) - $(stat -c %Y "$cache_file") ))
        [[ $cache_age -lt $CACHE_TIMEOUT_SECS ]]
    else
        return 1
    fi
}

# Function to check if failure cache is fresh
is_failure_cache_fresh() {
    local failure_cache_file="$1"
    if [[ -f "$failure_cache_file" ]]; then
        local cache_age=$(( $(date +%s) - $(stat -c %Y "$failure_cache_file") ))
        [[ $cache_age -lt $FAILURE_CACHE_TIMEOUT_SECS ]]
    else
        return 1
    fi
}

# Function to display cached content with truncation
display_cached_content() {
    local cache_file="$1"
    local content
    content=$(cat "$cache_file")

    if [[ ${#content} -gt 60 ]]; then
        # Truncate to 59 chars and add ellipsis
        echo "${content:0:59}…"
    else
        echo "$content"
    fi
}

# Function to check if background job is already running
is_background_job_running() {
    local lock_file="$1"

    if [[ -f "$lock_file" ]]; then
        local lock_pid
        lock_pid=$(cat "$lock_file" 2>/dev/null || echo "")

        # Check if the process is still running
        if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            return 0  # Job is running
        else
            # Stale lock file, remove it
            rm -f "$lock_file"
            return 1  # Job not running
        fi
    else
        return 1  # No lock file, job not running
    fi
}

# Function to run AI in background
run_ai_background() {
    local log_content="$1"
    local cache_file="$2"
    local cache_key="$3"
    local ai_command="$4"
    local lock_file="$cache_file.lock"
    local temp_file="$cache_file.tmp.$$"
    local failure_cache_file="$cache_file.failure"

    # Check if job is already running
    if is_background_job_running "$lock_file"; then
        return 0  # Job already running, don't start another
    fi

    # Start fully detached background process using nohup
    nohup bash -c "
        # Create lock file with our PID
        echo \$\$ > '$lock_file'

        # Create sessions directory and run AI from there
        # (otherwise sessions accumulate in the project dirs)
        sessions_dir='$CACHE_DIR/sessions'
        mkdir -p \"\$sessions_dir\"
        cd \"\$sessions_dir\"

        # Set timeout for the entire operation
        if timeout '$AI_TIMEOUT_SECS' $ai_command > '$temp_file' 2>/dev/null; then
            # Post-process: replace newlines with spaces, keep full content in cache
            tr '\\n' ' ' < '$temp_file' > '$cache_file'
        else
            # AI call failed/timed out - create failure cache
            echo '(analyzing failed)' > '$failure_cache_file'
        fi

        # Clean up temp file and lock file
        rm -f '$temp_file' '$lock_file'
    " >/dev/null 2>&1 <<EOF &
Summarize this commit log in under 40 characters, fit as much specific detail as possible in the limit. Output only the summary.

$log_content
EOF
}

# Function to clean old cache files
cleanup_cache() {
    # Convert seconds to days/minutes with ceiling division (round up)
    local cache_timeout_days=$(((CACHE_TIMEOUT_SECS + 86399) / 86400))
    local failure_timeout_mins=$(((FAILURE_CACHE_TIMEOUT_SECS + 59) / 60))
    local ai_timeout_mins=$(((AI_TIMEOUT_SECS + 59) / 60))

    # Remove cache files older than cache timeout
    find "$CACHE_DIR" -name "*.cache" -mtime "+$cache_timeout_days" -delete 2>/dev/null || true
    # Remove failure cache files older than failure timeout
    find "$CACHE_DIR" -name "*.failure" -mmin "+$failure_timeout_mins" -delete 2>/dev/null || true
    # Remove temp files older than AI timeout
    find "$CACHE_DIR" -name "*.tmp.*" -mmin "+$ai_timeout_mins" -delete 2>/dev/null || true
    # Remove stale lock files (older than AI timeout)
    find "$CACHE_DIR" -name "*.lock" -mmin "+$ai_timeout_mins" -delete 2>/dev/null || true
}

# Main logic
main() {
    # Get log content
    local log_content
    log_content=$(get_log_content)

    # If no log content, exit silently
    if [[ -z "$log_content" ]]; then
        exit 0
    fi

    # Generate cache key
    local cache_key
    cache_key=$(generate_cache_key "$log_content" "$MODEL")
    local cache_file="$CACHE_DIR/${cache_key}.cache"
    local failure_cache_file="$cache_file.failure"

    # Get AI command for this model
    local ai_command
    ai_command=$(get_ai_command "$MODEL")

    # Check if we have a fresh cache hit
    if is_cache_fresh "$cache_file"; then
        display_cached_content "$cache_file"
        exit 0
    fi

    # Check if we have a fresh failure cache - don't retry if recent failure
    if is_failure_cache_fresh "$failure_cache_file"; then
        cat "$failure_cache_file"
        exit 0
    fi

    # Cache miss - check if we have stale cache
    if [[ -f "$cache_file" ]]; then
        # Show stale cache and refresh in background
        display_cached_content "$cache_file"
        run_ai_background "$log_content" "$cache_file" "$cache_key" "$ai_command"
        exit 0
    fi

    # No cache at all - show placeholder and start background job
    echo "(analyzing...)"
    run_ai_background "$log_content" "$cache_file" "$cache_key" "$ai_command"

    # Clean up old cache files occasionally (1 in 10 chance)
    if (( RANDOM % 10 == 0 )); then
        cleanup_cache
    fi
}

main "$@"
