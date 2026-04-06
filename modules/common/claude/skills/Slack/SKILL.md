---
name: Slack
description: Interact with Slack workspaces using browser automation. USE WHEN the user needs to check unread channels, send messages, search conversations, navigate Slack, or extract data from Slack workspaces without using the Slack API.
allowed-tools: Bash(agent-browser:*)
---

You automate Slack workspace interactions using browser automation via `agent-browser`.

## When Invoked

1. **Read References**: You MUST read the Slack task reference before proceeding:
   @./reference/slack-tasks.md

2. **Gather Context**: Determine whether Slack is already open in a browser session:
   - If Slack is already running in a browser, connect via `agent-browser connect 9222`
   - If Slack is not running, open it with `agent-browser open https://app.slack.com`

3. **Determine Intent**: Analyze the user's request to identify:
   - Do they want to check unreads? Read a channel? Send a message?
   - Do they need to search for something?
   - Do they need to extract structured data?

4. **Execute Task**: Take a snapshot to understand current page state, then perform the task using refs from the snapshot.

5. **Report Results**: Summarize what was found or accomplished. Include screenshots for visual evidence.

## Core Workflow

Every Slack automation follows this pattern:

1. **Connect**: `agent-browser connect 9222` (if Slack is open) or `agent-browser open https://app.slack.com`
2. **Snapshot**: `agent-browser snapshot -i` to get element refs
3. **Navigate**: Click tabs, channels, or sections using refs
4. **Interact**: Read data, send messages, or search
5. **Re-snapshot**: After navigation, get fresh refs for the new page state

## Essential Commands

```bash
# Connect to existing Slack session
agent-browser connect 9222

# Or open Slack fresh
agent-browser open https://app.slack.com

# Get interactive elements with refs
agent-browser snapshot -i

# Click an element by ref
agent-browser click @e14

# Fill a search or message input
agent-browser fill @e_search "keyword"

# Press a key (e.g., Enter to submit)
agent-browser press Enter

# Take a screenshot
agent-browser screenshot slack-state.png

# Get text from an element
agent-browser get text @e1

# Scroll within the sidebar
agent-browser scroll down 300 --selector ".p-sidebar"

# Wait for page to settle
agent-browser wait 1000
```

## Common Task Routing

| Task | Description |
|------|-------------|
| Check unreads | Connect, snapshot, navigate to Activity tab or expand "More unreads" |
| Read a channel | Find channel in sidebar, click it, snapshot to read messages |
| Send a message | Navigate to channel, find message input, fill and press Enter |
| Search conversations | Click search button, fill query, press Enter, review results |
| Extract data | Use `snapshot --json` for structured, machine-readable output |

## Sidebar Structure

Slack's sidebar elements to look for:

```
- Threads
- Huddles
- Drafts & sent
- Directories
- [Section Headers: External connections, Starred, Channels, etc.]
  - [Channels listed as treeitems]
- Direct Messages
  - [DMs listed]
- Apps
- [More unreads] button
```

Typical ref ranges (vary by session):
- `@e12` — Home tab
- `@e13` — DMs tab
- `@e14` — Activity tab
- `@e5` — Search button
- `@e21` — More unreads button

## Tips

- **Connect to existing sessions**: `agent-browser connect 9222` is faster than opening a new browser when Slack is already running.
- **Snapshot before acting**: Always `snapshot -i` to identify refs before clicking.
- **Re-snapshot after navigation**: Refs change after navigating to a new page or channel.
- **JSON snapshots for parsing**: Use `snapshot --json` when you need structured data to process programmatically.
- **Pace interactions**: Add `agent-browser wait 1000` between rapid interactions to let the UI settle.
- **Include cursor-interactive elements**: Use `snapshot -i -C` if a clickable element is not showing up in the default snapshot.
- **Authentication**: Session persistence handles login state — no API credentials needed.

## Reference

- [Slack Tasks](./reference/slack-tasks.md)
