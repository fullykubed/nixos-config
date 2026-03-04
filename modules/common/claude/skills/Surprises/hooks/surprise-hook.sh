#!/usr/bin/env bash

# Claude Code surprise hook
# Fires at the end of every conversation to review files read for documentation surprises

set -euo pipefail

# Read JSON input from stdin (always provided by hooks)
input=$(cat)

# Guard against recursive invocation from our own claude calls
if [ "${CLAUDE_HOOK_RECURSIVE:-}" = "1" ]; then
    exit 0
fi

# Extract fields from the JSON payload
transcript_path=$(echo "$input" | @jq@ -r '.transcript_path // ""')
stop_hook_active=$(echo "$input" | @jq@ -r '.stop_hook_active // false')
cwd=$(echo "$input" | @jq@ -r '.cwd // ""')

# Also exit if stop_hook_active is true (another stop hook is already running)
if [ "$stop_hook_active" = "true" ]; then
    exit 0
fi

# Exit if no transcript path or file doesn't exist
if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    exit 0
fi

# Parse transcript JSONL to extract all file paths from Read tool_use entries, deduplicated
read_files=$(@jq@ -r '
  select(.message.role == "assistant") |
  .message.content[]? |
  select(.type == "tool_use" and .name == "Read") |
  .input.file_path // empty
' "$transcript_path" | sort -u)

# Exit if no files were read during the conversation
if [ -z "$read_files" ]; then
    exit 0
fi

# Resolve the default branch worktree path (bare-repo safe)
MAIN_WORKTREE=$(git-worktree-path) || exit 0
if [ -z "$MAIN_WORKTREE" ]; then
    exit 0
fi

# Ensure the surprises directory exists in the main worktree
mkdir -p "$MAIN_WORKTREE/.claude/surprises"

# Create a condensed transcript (~90% smaller): keep user/assistant messages,
# strip tool_result content, drop thinking blocks, drop non-message lines
# (progress, snapshots, queue ops), and drop per-message envelope metadata.
condensed_transcript=$(mktemp "${TMPDIR:-/tmp}/surprise-transcript.XXXXXX")
@jq@ -c '
  select(.type == "user" or .type == "assistant") |
  if .type == "user" then
    {type, message: {role: .message.role, content: [
      .message.content[]? |
      if .type == "tool_result" then
        if .is_error then .
        else {type: "tool_result", tool_use_id: .tool_use_id, content: "(omitted)"}
        end
      else .
      end
    ]}}
  elif .type == "assistant" then
    {type, message: {role: .message.role, content: [
      .message.content[]? |
      select(.type != "thinking")
    ]}}
  else .
  end
' "$transcript_path" > "$condensed_transcript"

# Build a file list for the prompt
file_list=""
while IFS= read -r f; do
    file_list="${file_list}- ${f}
"
done <<< "$read_files"

# Build the prompt for the surprise-reviewer agent
prompt="Review the following files for surprises.

Condensed transcript path: ${condensed_transcript}
Main worktree: ${MAIN_WORKTREE}
Working directory: ${cwd}

Files read during the conversation:
${file_list}"

# Fork the surprise-reviewer agent in the background (non-blocking)
(
    CLAUDE_HOOK_RECURSIVE=1 @claude@ \
        --agent surprise-reviewer \
        --print \
        --no-session-persistence \
        "$prompt" \
        2>/dev/null
    rm -f "$condensed_transcript"
) &

exit 0
