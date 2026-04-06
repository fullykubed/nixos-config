# agent-browser Command Reference

Full reference for all agent-browser CLI commands.

## Command Syntax

All commands use the pattern:

```bash
agent-browser [--session <name>] <command> [args] [options]
```

The `--session` flag must come **before** the subcommand. Omitting `--session` uses the "default" session.

## Navigation

```bash
agent-browser --session <id> open <url>     # Navigate to URL (aliases: goto, navigate)
agent-browser --session <id> back           # Go back in history
agent-browser --session <id> forward        # Go forward in history
agent-browser --session <id> reload         # Reload current page
agent-browser --session <id> close          # Close browser (aliases: quit, exit)
```

## Snapshot

```bash
agent-browser --session <id> snapshot          # Full accessibility tree
agent-browser --session <id> snapshot -i       # Interactive elements only (recommended)
agent-browser --session <id> snapshot -i -C    # Include cursor-interactive elements (divs with onclick, cursor:pointer)
agent-browser --session <id> snapshot -c       # Compact (remove empty structural elements)
agent-browser --session <id> snapshot -d 3     # Limit depth to 3 levels
agent-browser --session <id> snapshot -s "#main"  # Scope to CSS selector
agent-browser --session <id> snapshot --json   # JSON format output
```

| Option | Description |
|--------|-------------|
| `-i, --interactive` | Only interactive elements (buttons, links, inputs) |
| `-C, --cursor` | Include cursor-interactive elements (cursor:pointer, onclick) |
| `-c, --compact` | Remove empty structural elements |
| `-d, --depth` | Limit tree depth |
| `-s, --scope` | Scope to a CSS selector |
| `--json` | JSON output for programmatic parsing |

## Element Interaction

```bash
agent-browser --session <id> click <sel>              # Click element
agent-browser --session <id> dblclick <sel>           # Double-click element
agent-browser --session <id> focus <sel>              # Focus element
agent-browser --session <id> hover <sel>              # Hover over element
agent-browser --session <id> fill <sel> <text>        # Clear and fill input
agent-browser --session <id> type <sel> <text>        # Type character by character
agent-browser --session <id> clear <sel>              # Clear input field
agent-browser --session <id> select <sel> <value>     # Select option in dropdown
agent-browser --session <id> check <sel>              # Check a checkbox
agent-browser --session <id> uncheck <sel>            # Uncheck a checkbox
agent-browser --session <id> press <key>              # Press a keyboard key
agent-browser --session <id> scroll <dir> [px]        # Scroll page (up/down/left/right)
```

Selectors can be snapshot refs (`@e1`), CSS selectors, IDs, or text.

## Get Information

```bash
agent-browser --session <id> get text <sel>           # Get element text content
agent-browser --session <id> get html <sel>           # Get element innerHTML
agent-browser --session <id> get value <sel>          # Get input value
agent-browser --session <id> get attr <sel> <attr>    # Get element attribute
```

## Wait

```bash
agent-browser --session <id> wait <selector>          # Wait for element to be visible
agent-browser --session <id> wait <ms>                # Wait for time (milliseconds)
agent-browser --session <id> wait --text "Welcome"    # Wait for text to appear
agent-browser --session <id> wait --url "**/dash"     # Wait for URL pattern
agent-browser --session <id> wait --load networkidle  # Wait for network activity to settle
```

## Capture

```bash
agent-browser --session <id> screenshot [path]        # Screenshot (to temp dir if no path)
agent-browser --session <id> screenshot --annotate [path]  # Annotated screenshot with numbered labels
agent-browser --session <id> screenshot --full [path] # Full-page screenshot
agent-browser --session <id> pdf <path>               # Save page as PDF
```

## JavaScript Evaluation

```bash
agent-browser --session <id> eval <js>                # Run JavaScript in page context
agent-browser --session <id> eval --stdin             # Read JS from stdin (avoids shell quoting issues)
```

**Shell quoting tip**: For complex expressions, use `--stdin` to avoid quoting issues:

```bash
echo "document.querySelectorAll('a').length" | agent-browser --session <id> eval --stdin
```

## Find Elements (Semantic Locators)

```bash
agent-browser --session <id> find role "button" click      # Find by ARIA role
agent-browser --session <id> find text "Submit" click      # Find by visible text
agent-browser --session <id> find testid "submit-btn" click  # Find by data-testid
```

Supported actions: `click`, `fill`, `type`, `hover`, `focus`, `check`, `uncheck`, `text`.

## Diff

```bash
agent-browser --session <id> diff snapshot             # Compare current vs last snapshot
```

Useful for verifying that an action had the intended effect.

## Session Commands

```bash
agent-browser session                                  # Show current session name
agent-browser session list                             # List all active sessions
```

## State Management

```bash
agent-browser state save <path>                        # Save auth state to file
agent-browser state load <path>                        # Load auth state from file
agent-browser state list                               # List all saved states
agent-browser state show <file>                        # Show state summary
agent-browser state clean --older-than <days>          # Delete old states
```

## Global Options

These options apply to all commands:

| Option | Description |
|--------|-------------|
| `--session <name>` | Named browser session (must come before subcommand) |
| `--timeout <ms>` | Command timeout in milliseconds (default: 25000) |
| `--headed` | Show browser window (useful for debugging) |
| `--json` | JSON output |
| `--full, -f` | Full-page screenshot |
| `--executable-path <path>` | Custom browser executable |

## Chaining Commands

Chain commands with `&&` for efficiency when you don't need to parse intermediate output:

```bash
agent-browser --session s1 open example.com && agent-browser --session s1 wait --load networkidle && agent-browser --session s1 snapshot -i
```

Run commands separately when you need to parse output first.
