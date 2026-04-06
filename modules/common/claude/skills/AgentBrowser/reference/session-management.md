# Session Management

agent-browser supports multiple isolated browser sessions. Each session has its own authentication state, navigation history, cookies, and browser instance.

## Basic Session Usage

Specify a session with `--session` **before** the subcommand:

```bash
agent-browser --session my-session open "https://example.com"
agent-browser --session my-session snapshot -i
agent-browser --session my-session click @e1
agent-browser --session my-session close
```

Omitting `--session` uses the "default" session.

## Auto-Start

The browser daemon starts automatically on the first command — no explicit start step needed. Just run any command and the daemon will start if it isn't already running.

## Named Sessions

Use named sessions when running multiple concurrent automations to avoid conflicts:

```bash
# Each agent gets its own isolated session
agent-browser --session agent1 open site-a.com
agent-browser --session agent2 open site-b.com

# Sessions don't interfere with each other
agent-browser --session agent1 snapshot -i
agent-browser --session agent2 snapshot -i
```

Or via environment variable:

```bash
export AGENT_BROWSER_SESSION=agent1
agent-browser open site-a.com
agent-browser click @e1
```

## Listing Active Sessions

```bash
agent-browser session list
# Output:
# Active sessions:
# -> default
#    agent1
#    agent2
```

## Session Isolation

Each session maintains its own:
- Authentication state (cookies, localStorage, sessionStorage)
- Navigation history (back/forward)
- Browser instance and tabs
- In-progress form data

## Auto-Cleanup

Sessions auto-terminate after 30 minutes of inactivity. Always close sessions explicitly when done to avoid leaked processes:

```bash
agent-browser close                          # Close default session
agent-browser --session agent1 close         # Close specific session
```

## State Persistence

By default, browser state is lost when the browser closes. For persistent auth across restarts:

```bash
# Save state (cookies, localStorage) to a file
agent-browser state save /tmp/my-app-state.json

# Load state in a new session
agent-browser --session new-session open "https://app.example.com"
agent-browser state load /tmp/my-app-state.json
```

Use `--session-name` for automatic save/load across browser restarts:

```bash
# State is auto-saved and restored for this named session
agent-browser --session-name myapp open "https://app.example.com/login"
# Login once...
agent-browser --session-name myapp fill @e1 "user@example.com"
agent-browser --session-name myapp click @e2
# Next run, state is automatically restored
```

State files are stored in `~/.agent-browser/sessions/`.

## State Management Commands

```bash
agent-browser state list                              # List all saved states
agent-browser state show <file>                       # Show state summary (cookies, origins)
agent-browser state rename <old-name> <new-name>      # Rename a state file
agent-browser state clear <session-name>              # Clear states for a session
agent-browser state clear --all                       # Clear all saved states
agent-browser state clean --older-than <days>         # Delete old states
```

## Parallel Scraping

Named sessions enable concurrent scraping across multiple sites:

```bash
# Run in parallel (background processes)
agent-browser --session scraper1 open "https://site-a.com" &
agent-browser --session scraper2 open "https://site-b.com" &
wait

# Collect results
agent-browser --session scraper1 eval "document.title"
agent-browser --session scraper2 eval "document.title"

# Clean up
agent-browser --session scraper1 close
agent-browser --session scraper2 close
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `AGENT_BROWSER_SESSION` | Browser session ID (default: "default") |
| `AGENT_BROWSER_SESSION_NAME` | Auto-save/load state persistence name |
| `AGENT_BROWSER_STATE_EXPIRE_DAYS` | Auto-delete states older than N days (default: 30) |

## Best Practices

- Always use named sessions when running multiple concurrent automations
- Always close sessions explicitly when done (`agent-browser --session <id> close`)
- Use the same `--session` ID across related commands to maintain state
- Use `state save`/`state load` for authenticated sessions that need to persist
- Check `session list` if you suspect leaked sessions from a previous run
