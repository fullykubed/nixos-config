#!/usr/bin/env bash
claude -p --dangerously-skip-permissions --model opus --tools "" --allowedTools "WebSearch" --system-prompt "You answer questions concisely for terminal output. Use WebSearch to find current information when needed. Format responses in markdown, keeping them under 50 lines. Be direct and factual. Include sources when citing specific facts." "$*" | glow
