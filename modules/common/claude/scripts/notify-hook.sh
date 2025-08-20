#!/usr/bin/env bash

# Claude Code notification hook
# Sends a desktop notification when Claude needs user input

# Read JSON input from stdin (always provided by hooks)
input=$(cat)

# Extract hook event name from the JSON payload
HOOK_TYPE=$(echo "$input" | @jq@ -r '.hook_event_name // ""')

# Extract session ID from the JSON payload
SESSION_ID=$(echo "$input" | @jq@ -r '.session_id // ""')

# Mark for this Claude session's container (include both session ID and pane for uniqueness)
if [ -n "$SESSION_ID" ] && [ -n "$TMUX_PANE" ]; then
    CLAUDE_MARK="claude_${SESSION_ID}_${TMUX_PANE}"
elif [ -n "$SESSION_ID" ]; then
    CLAUDE_MARK="claude_${SESSION_ID}"
else
    CLAUDE_MARK="claude_${TMUX_PANE:-$$}"
fi

# Function to send notification
send_notification() {
    local title="$1"
    local body="$2"
    local urgency="${3:-normal}"
    
    # Send desktop notification
    local extra_args=""
    if [ "$4" = "transient" ]; then
        extra_args="--transient"
    fi
    
    # If we're in tmux, send notification with dismissal on focus
    if [ -n "$TMUX_PANE" ] && [ "$4" != "transient" ]; then
        echo "[DEBUG] Sending notification, mark=$CLAUDE_MARK, pane=$TMUX_PANE" >> /tmp/claude-notify.log
        
        # Send notification and get ID for dismissal
        local notification_id=$(@notify-send@ \
            --urgency="$urgency" \
            --app-name="claude-code" \
            --icon="dialog-information" \
            --expire-time=5000 \
            --print-id \
            $extra_args \
            "$title" \
            "$body")
        
        echo "[DEBUG] Notification sent, id=$notification_id" >> /tmp/claude-notify.log
        
        # Set a tmux hook to dismiss notification when this pane gains focus
        
            tmux set-hook -t "$TMUX_PANE" pane-focus-in "run-shell 'gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.CloseNotification $notification_id 2>/dev/null || true; tmux select-pane -t $TMUX_PANE; tmux set-hook -ut $TMUX_PANE pane-focus-in'"
        
        
        # Now replace the notification with one that has an action and wait for response
        (
            echo "[DEBUG] Replacing notification with action version" >> /tmp/claude-notify.log
            
            # Replace notification with action version and wait for response
            action=$(@notify-send@ \
                --urgency="$urgency" \
                --app-name="claude-code" \
                --icon="dialog-information" \
                --expire-time=5000 \
                --replace-id="$notification_id" \
                --action="focus=Focus Pane" \
                $extra_args \
                "$title" \
                "$body")
            
            echo "[DEBUG] Action response: '$action'" >> /tmp/claude-notify.log
            
            # If user clicked the focus action
            if [ "$action" = "focus" ]; then
                echo "[DEBUG] Focusing container with mark: $CLAUDE_MARK" >> /tmp/claude-notify.log
                swaymsg "[con_mark=\"$CLAUDE_MARK\"] focus"
		tmux set-hook -ut $TMUX_PANE pane-focus-in
                tmux select-window -t "$TMUX_PANE"
                tmux select-pane -t "$TMUX_PANE"
                echo "[DEBUG] Focus completed" >> /tmp/claude-notify.log
            fi
        ) &
    else
        # Simple notification without action
        @notify-send@ \
            --urgency="$urgency" \
            --app-name="claude-code" \
            --icon="dialog-information" \
            --expire-time=5000 \
            $extra_args \
            "$title" \
            "$body"
    fi
}

# Function to set tmux window alert and background
set_tmux_alert_background() {
    if [ -n "$TMUX" ]; then
        # Get the pane ID where this script is running (Claude's pane)
        local pane_id="$TMUX_PANE"
        
        # Check if Claude's pane is currently active
        local active_pane=$(tmux display-message -p '#{pane_id}')
        if [ "$pane_id" != "$active_pane" ]; then
            # Set light orange background for Claude's pane only if not focused
            # The tmux config's pane-focus-in hook will automatically reset this
            # Use set-option to set pane-specific style without selecting it
            tmux set-option -t "$pane_id" -p window-style 'bg=#2a1f1a'
        fi
        
        # Get Claude's window ID
        local window_id=$(tmux display-message -t "$pane_id" -p '#{window_id}')
        local active_window=$(tmux display-message -p '#{window_id}')
        
        # Only change window name if Claude's window is not currently focused
        if [ "$window_id" != "$active_window" ]; then
            # Set activity flag on Claude's window to trigger visual indicator
            tmux set-window-option -t "$pane_id" monitor-activity on
            tmux send-keys -t "$pane_id" "" # Trigger activity by sending empty input
            
            # Rename the window temporarily to show alert
            local window_name=$(tmux display-message -t "$pane_id" -p '#{window_name}')
            
            # Check if window name doesn't already have the red dot
            if [[ "$window_name" != "🔴 "* ]]; then
                tmux rename-window -t "$pane_id" "🔴 $window_name"
                
                # Set up hook to restore window name when window gains focus
                tmux set-hook -g after-select-window "if -F '#{==:#{window_id},$window_id}' 'rename-window -t $window_id \"${window_name}\" ; set-hook -gu after-select-window' ''"
            fi
        fi
    fi
}

# Handle different hook types
case "$HOOK_TYPE" in
    "PreToolUse")
        send_notification "Claude Code - Tool Use" "About to use a tool" "normal"
        ;;
    "PostToolUse")
        send_notification "Claude Code - Tool Complete" "Tool execution completed" "normal"
        ;;
    "Notification")
        # Extract message from the JSON payload for notifications
        message=$(echo "$input" | @jq@ -r '.message // "Needs your input"')
        send_notification "Claude Needs Input" "$message" "critical"
        set_tmux_alert_background
        ;;
    "UserPromptSubmit")
        # Mark the Sway container containing this tmux session (only on first prompt)
        if [ -n "$TMUX_PANE" ]; then
            # Check if mark already exists
            if ! swaymsg -t get_marks | grep -q "\"$CLAUDE_MARK\""; then
                # Get the PID of the terminal containing this tmux session
                # First get the tmux client's tty
                client_pid=$(tmux list-clients -F '#{client_pid}' -t "$TMUX_PANE" | head -1)
                
                if [ -n "$client_pid" ]; then
                    # Find the terminal emulator process (parent of the tmux client)
                    term_pid=$(ps -o ppid= -p "$client_pid" | tr -d ' ')
                    
                    echo "[DEBUG] Marking container: client_pid=$client_pid, term_pid=$term_pid, mark=$CLAUDE_MARK" >> /tmp/claude-notify.log
                    
                    if [ -n "$term_pid" ]; then
                        # Mark the Sway container with this PID
                        mark_result=$(swaymsg "[pid=$term_pid] mark --add $CLAUDE_MARK" 2>&1)
                        echo "[DEBUG] Mark result: $mark_result" >> /tmp/claude-notify.log
                        
                        # If that didn't work, try marking the focused container
                        if echo "$mark_result" | grep -q "No matching node"; then
                            echo "[DEBUG] PID not found, marking focused container instead" >> /tmp/claude-notify.log
                            mark_result=$(swaymsg "mark --add $CLAUDE_MARK" 2>&1)
                            echo "[DEBUG] Focused mark result: $mark_result" >> /tmp/claude-notify.log
                        fi
                    fi
                fi
            fi
        fi
        ;;
    "Stop")
        # For stop hook, check if we're being called recursively
        if [ "$CLAUDE_HOOK_RECURSIVE" = "1" ]; then
            # Don't process if this is a recursive call from our own claude invocation
            exit 0
        fi
        
        # Remove the Sway container mark when session ends
        if [ -n "$TMUX_PANE" ]; then
            swaymsg "[con_mark=\"$CLAUDE_MARK\"] unmark"
        fi
        
        # For stop hook, get transcript and generate summary
        transcript_path=$(echo "$input" | @jq@ -r '.transcript_path // ""')
        if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
            # Extract only user and assistant messages from the JSONL transcript
            # Use the extract-conversation script to get clean human-readable text
            # Use Claude to generate a brief summary (max 10 words)
            # Set environment variable to prevent recursive hook calls
            script_dir="$(dirname "${BASH_SOURCE[0]}")"
            conversation=$(cat "$transcript_path" | "$script_dir/extract-conversation.sh" | tail -c 5000)
            summary=$(echo "$conversation" | CLAUDE_HOOK_RECURSIVE=1 @claude@ --model sonnet --append-system-prompt "Summarize what was accomplished in this conversation in 10 words or less. Be specific about the main task completed and focus on the last updates from the assistant since the last user text. Output only the summary, nothing else." --print "summarize:" 2>/dev/null || echo "Session complete")
            send_notification "Claude Finished" "$summary" "normal"
        else
            send_notification "Claude Finished" "Session complete" "normal"
        fi
        set_tmux_alert_background
        ;;
    "SubagentStop")
        send_notification "Claude Code" "Subagent task completed" "normal" "transient"
        ;;
    "PreCompact")
        send_notification "Claude Code" "Compacting conversation history" "normal"
        ;;
    "SessionStart")
        send_notification "Claude Code" "New session started" "normal"
        ;;
    *)
        # Unknown hook type - log it for debugging
        if [ -n "$HOOK_TYPE" ]; then
            send_notification "Claude Code" "Unknown hook: $HOOK_TYPE" "normal"
        fi
        ;;
esac

exit 0
