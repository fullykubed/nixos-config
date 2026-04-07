#!/usr/bin/env bash

# Claude Code notification hook
# Sends a Pushover notification summarising the last assistant message when
# user is away.
#
# Claude Code 2.x populates `last_assistant_message` directly in the Stop hook
# payload. We pipe that text through `llm-summarize` (a one-shot Bun tool that
# talks directly to the Anthropic Messages API — NEVER spawns `claude`, so
# this hook cannot trigger itself) to produce a phone-notification-quality
# one-liner. On any failure we fall back to the raw 500-char truncation so
# the notification ALWAYS fires when the user is away.

input=$(cat)

HOOK_TYPE=$(echo "$input" | @jaq@ -r '.hook_event_name // ""')

case "$HOOK_TYPE" in
    "Stop")
        # Only notify when user is away — saves spam when actively working.
        if ! is-away; then
            exit 0
        fi

        raw=$(echo "$input" | @jaq@ -r '.last_assistant_message // "Session complete"')

        # Try to generate a concise phone-notification-quality summary.
        # Fall back to the raw truncated body on any failure — notifications
        # MUST always fire, even if the LLM call breaks.
        summary=$(
            printf '%s' "$raw" | @llm-summarize@ \
                --instructions "Summarise what Claude just did in a single sentence (max 150 characters) for a phone push notification. Focus on the outcome (e.g. 'build passed', 'applied fix', 'stuck on X'), not the process." \
                --max-tokens 80 \
                2>/dev/null
        ) || summary="${raw:0:500}"

        # Belt-and-suspenders: if the summariser exited 0 but printed nothing,
        # still fall back to the raw body.
        if [ -z "$summary" ]; then
            summary="${raw:0:500}"
        fi

        notify-if-away --force "Claude Finished" "$summary" || true
        ;;
esac

exit 0
