---
name: AgentBrowser
description: Browser automation for development testing, web scraping, and UI verification. USE WHEN you need to interact with web pages, verify UI changes, take screenshots, or extract data from websites.
allowed-tools: Bash(agent-browser:*)
---

You control a headless Chromium browser for web automation tasks. This skill provides CLI commands to navigate, interact with, and inspect web pages. The daemon starts automatically on first use — no explicit start command needed.

## When Invoked

1. **Determine Action**: Based on the user's request:
   - Need to view a page? → Use `open` then `snapshot`
   - Need to interact? → Use `click`, `fill`, or `eval`
   - Need visual verification? → Use `screenshot`
   - Need to wait for content? → Use `wait`

2. **Execute Commands**: Use the appropriate CLI commands via Bash tool

3. **Report Results**: Summarize what you found or accomplished

## Session Management

Sessions persist browser state (cookies, localStorage) across commands. Use `--session` before the subcommand to specify a named session.

- **Default session**: If `--session` is omitted, the "default" session is used
- **Multiple sessions**: Different agents can use different session IDs
- **Auto-cleanup**: Sessions auto-terminate after 30 minutes of inactivity

## Command Reference

| Command | Usage | Description |
|---------|-------|-------------|
| `open` | `agent-browser --session <id> open <url>` | Navigate to URL |
| `snapshot` | `agent-browser --session <id> snapshot -i` | Get interactive elements with refs |
| `click` | `agent-browser --session <id> click <ref\|selector>` | Click element |
| `fill` | `agent-browser --session <id> fill <ref\|selector> <text>` | Clear and fill input |
| `screenshot` | `agent-browser --session <id> screenshot [path]` | Take screenshot |
| `eval` | `agent-browser --session <id> eval <script>` | Run JavaScript |
| `wait` | `agent-browser --session <id> wait <ref\|selector>` | Wait for element |
| `close` | `agent-browser --session <id> close` | Close browser session |

See [commands.md](./reference/commands.md) for the full command set.

## Workflow Routing

| Workflow | Trigger Words | When to Use |
|----------|---------------|-------------|
| [BrowseWeb](./workflows/BrowseWeb.md) | "browse", "open", "navigate", "check", "verify", "screenshot", "scrape" | User wants to interact with or inspect a web page |

## Reference

- [Commands](./reference/commands.md) — Full command reference with all options
- [Snapshot Refs](./reference/snapshot-refs.md) — The @e1, @e2 locator system
- [Session Management](./reference/session-management.md) — Named sessions, state persistence

## Tips

- Always use `snapshot -i` after navigation to understand page structure
- Use the locators (@e1, @e2) from snapshot for click/fill selectors — they are the most reliable
- Re-snapshot after navigation or DOM changes; refs are invalidated on page changes
- Keep the same `--session` ID across related commands to maintain state
- Use `screenshot --annotate` for visual context alongside text snapshots
