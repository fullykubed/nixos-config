---
name: DevBrowser
description: Browser automation for development testing, web scraping, and UI verification. USE WHEN you need to interact with web pages, verify UI changes, take screenshots, or extract data from websites.
---

You control a headless Chromium browser for web automation tasks. This skill provides CLI commands to navigate, interact with, and inspect web pages.

## When Invoked

1. **Start a Session**: If not already running, start a browser session:
   ```bash
   dev-browser start --session my-session
   ```

2. **Determine Action**: Based on the user's request:
   - Need to view a page? → Use `navigate` then `snapshot`
   - Need to interact? → Use `click`, `type`, or `eval`
   - Need visual verification? → Use `screenshot`
   - Need to wait for content? → Use `wait`

3. **Execute Commands**: Use the appropriate CLI commands via Bash tool

4. **Report Results**: Summarize what you found or accomplished

## Session Management

Sessions persist browser state (cookies, localStorage) across commands. Each session has a unique ID.

- **Default session**: If `--session` is omitted, a random UUID is generated
- **Multiple sessions**: Different agents can use different session IDs
- **Auto-cleanup**: Sessions auto-terminate after 30 minutes of inactivity

## Command Reference

| Command | Usage | Description |
|---------|-------|-------------|
| `start` | `dev-browser start --session <id>` | Start browser server |
| `stop` | `dev-browser stop --session <id>` | Stop browser server |
| `navigate` | `dev-browser navigate --session <id> <url>` | Go to URL |
| `snapshot` | `dev-browser snapshot --session <id>` | Get AI-optimized DOM |
| `click` | `dev-browser click --session <id> <selector>` | Click element |
| `type` | `dev-browser type --session <id> <selector> <text>` | Fill input |
| `screenshot` | `dev-browser screenshot --session <id> [--path <file>]` | Take screenshot |
| `eval` | `dev-browser eval --session <id> <script>` | Run JavaScript |
| `wait` | `dev-browser wait --session <id> <selector>` | Wait for element |

## Workflow Routing

| Workflow | Trigger Words | When to Use |
|----------|---------------|-------------|
| [BrowseWeb](./workflows/BrowseWeb.md) | "browse", "open", "navigate", "check", "verify", "screenshot", "scrape" | User wants to interact with or inspect a web page |

## Tips

- Always use `snapshot` after navigation to understand page structure
- Use the locators (@e1, @e2) from snapshot for click/type selectors
- Screenshots are base64-encoded by default; use `--path` to save to file
- Keep the same `--session` ID across related commands to maintain state
