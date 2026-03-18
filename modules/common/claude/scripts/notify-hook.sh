#!/usr/bin/env bash

# Claude Code notification hook
# Sends a Pushover notification with conversation summary when user is away

# Read JSON input from stdin (always provided by hooks)
input=$(cat)

# Extract hook event name from the JSON payload
HOOK_TYPE=$(echo "$input" | @jaq@ -r '.hook_event_name // ""')

# Handle different hook types
case "$HOOK_TYPE" in
    "Stop")
        # For stop hook, check if we're being called recursively
        if [ "$CLAUDE_HOOK_RECURSIVE" = "1" ]; then
            exit 0
        fi

        # Only notify when user is away — saves tokens by skipping summary generation
        if ! is-away; then
            exit 0
        fi

        # User is away — generate summary and notify via Pushover
        transcript_path=$(echo "$input" | @jaq@ -r '.transcript_path // ""')
        if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
            script_dir="$(dirname "${BASH_SOURCE[0]}")"
            conversation=$(cat "$transcript_path" | "$script_dir/extract-conversation.sh" | tail -c 5000)
            summary=$(echo "$conversation" | CLAUDE_HOOK_RECURSIVE=1 @claude@ --model haiku --append-system-prompt "Summarize what happened in this conversation in 30 words or less. Be specific about the main task. If user interaction is needed (e.g. approval, error to fix, question to answer), highlight that and what the required action is. Output only the summary, nothing else." --print "summarize:" 2>/dev/null || echo "Session complete")
            notify-if-away --force "Claude Finished" "$summary" || true
        else
            notify-if-away --force "Claude Finished" "Session complete" || true
        fi
        ;;
esac

exit 0
