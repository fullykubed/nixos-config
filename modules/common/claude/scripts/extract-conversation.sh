#!/usr/bin/env bash

# Extract human-readable conversation from Claude transcript
# Usage: ./extract-conversation.sh < transcript.jsonl
#    or: cat transcript.jsonl | ./extract-conversation.sh

jq -r '
    select(.message.role == "user" or .message.role == "assistant") |
    .message |
    select(.content) |
    "\(.role): \(
        if (.content | type) == "string" then
            .content
        elif (.content | type) == "array" then
            if .content[0].type == "text" and .content[0].text then
                .content[0].text
            elif .content[0].type == "tool_result" then
                empty
            else
                empty
            end
        else
            empty
        end
    )"' | grep -v '^\[{'