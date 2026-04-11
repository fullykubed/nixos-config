#!/usr/bin/env bash
CLAUDE_NO_SUMMARY=1 claude-wrapper -p --model opus --tools "" --allowedTools "WebSearch" --system-prompt "You answer questions concisely for terminal output. Use WebSearch to look up current information when needed. Format responses in markdown, keeping them under 50 lines. Be direct and factual. Include sources when citing specific facts." "$*" | glow
