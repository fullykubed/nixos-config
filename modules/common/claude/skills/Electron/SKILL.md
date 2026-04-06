---
name: Electron
description: Automate Electron desktop apps (VS Code, Slack, Discord, Figma, Notion, Spotify, etc.) via Chrome DevTools Protocol. USE WHEN the user needs to interact with an Electron desktop app, automate a native app, connect to a running Electron app, or test an Electron application.
allowed-tools: Bash(agent-browser:*)
---

Automate any Electron desktop app using agent-browser. Electron apps are built on Chromium and expose a Chrome DevTools Protocol (CDP) port that agent-browser can connect to, enabling the same snapshot-interact workflow used for web pages.

## Core Workflow

1. **Launch** the Electron app with remote debugging enabled
2. **Connect** agent-browser to the CDP port
3. **Snapshot** to discover interactive elements
4. **Interact** using element refs
5. **Re-snapshot** after navigation or state changes

```bash
# Launch an Electron app with remote debugging
slack --remote-debugging-port=9222

# Connect agent-browser to the app
agent-browser connect 9222

# Standard workflow from here
agent-browser snapshot -i
agent-browser click @e5
agent-browser screenshot slack-desktop.png
```

## Launching Electron Apps with CDP

Every Electron app supports `--remote-debugging-port` since it is built into Chromium.

**Important:** If the app is already running, quit it first, then relaunch with the flag. The `--remote-debugging-port` flag must be present at launch time.

### Linux

```bash
# Slack
slack --remote-debugging-port=9222

# VS Code
code --remote-debugging-port=9223

# Discord
discord --remote-debugging-port=9224

# Spotify
spotify --remote-debugging-port=9225
```

### macOS

```bash
# Slack
open -a "Slack" --args --remote-debugging-port=9222

# VS Code
open -a "Visual Studio Code" --args --remote-debugging-port=9223

# Discord
open -a "Discord" --args --remote-debugging-port=9224

# Figma
open -a "Figma" --args --remote-debugging-port=9225

# Notion
open -a "Notion" --args --remote-debugging-port=9226

# Spotify
open -a "Spotify" --args --remote-debugging-port=9227
```

## Connecting

```bash
# Connect to a specific port (all subsequent commands target connected app)
agent-browser connect 9222

# Or pass --cdp on each command without a persistent connect
agent-browser --cdp 9222 snapshot -i

# Auto-discover a running Chromium-based app
agent-browser --auto-connect snapshot -i
```

## Tab Management

Electron apps often have multiple windows or webviews. Use tab commands to list and switch between them:

```bash
# List all available targets (windows, webviews, etc.)
agent-browser tab

# Switch to a specific tab by index
agent-browser tab 2

# Switch by URL pattern
agent-browser tab --url "*settings*"
```

## Webview Support

Electron `<webview>` elements are automatically discovered when using `--native` mode. Webviews appear as separate targets in the tab list:

```bash
# Connect in native mode
agent-browser --native connect 9222

# List targets -- webviews appear alongside pages
agent-browser tab
# Example output:
#   0: [page]    Slack - Main Window     https://app.slack.com/
#   1: [webview] Embedded Content        https://example.com/widget

# Switch to a webview
agent-browser tab 1
agent-browser snapshot -i
```

**Note:** Webview support requires `--native` mode. The Playwright-based mode does not support webview targets.

## Common Patterns

### Inspect and Navigate an App

```bash
slack --remote-debugging-port=9222
sleep 3  # Wait for app to start
agent-browser connect 9222
agent-browser snapshot -i
agent-browser click @e10
agent-browser snapshot -i
```

### Take Screenshots of Desktop Apps

```bash
agent-browser connect 9222
agent-browser screenshot app-state.png
agent-browser screenshot --full full-app.png
agent-browser screenshot --annotate annotated-app.png
```

### Extract Data from a Desktop App

```bash
agent-browser connect 9222
agent-browser snapshot -i
agent-browser get text @e5
agent-browser snapshot --json > app-state.json
```

### Fill Forms in Desktop Apps

```bash
agent-browser connect 9222
agent-browser snapshot -i
agent-browser fill @e3 "search query"
agent-browser press Enter
agent-browser wait 1000
agent-browser snapshot -i
```

### Run Multiple Apps Simultaneously

Use named sessions to control multiple Electron apps at the same time:

```bash
agent-browser --session slack connect 9222
agent-browser --session vscode connect 9223

agent-browser --session slack snapshot -i
agent-browser --session vscode snapshot -i
```

## Color Scheme

Playwright overrides the color scheme to `light` by default when connecting via CDP. To preserve dark mode:

```bash
agent-browser connect 9222
agent-browser --color-scheme dark snapshot -i
```

Or set it globally for the session:

```bash
AGENT_BROWSER_COLOR_SCHEME=dark agent-browser connect 9222
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Connection refused" | Ensure the app was launched with `--remote-debugging-port=NNNN` |
| App running but connect fails | Quit and relaunch with the flag; wait a few seconds after launch (`sleep 3`) |
| Port in use | Check with `lsof -i :9222`; use a different port number |
| Elements missing from snapshot | Use `agent-browser tab` to list targets; app may use multiple webviews |
| Cannot type in input fields | Try `agent-browser keyboard type "text"` or `agent-browser keyboard inserttext "text"` for custom inputs |

## Supported Apps

Any app built on Electron works, including:

- **Communication:** Slack, Discord, Microsoft Teams, Signal, Telegram Desktop
- **Development:** VS Code, GitHub Desktop, Postman, Insomnia
- **Design:** Figma, Notion, Obsidian
- **Media:** Spotify, Tidal
- **Productivity:** Todoist, Linear, 1Password
