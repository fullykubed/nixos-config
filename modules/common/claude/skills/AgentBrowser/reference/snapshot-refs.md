# Snapshot Refs (@e1, @e2, ...)

The snapshot ref system is agent-browser's core innovation for token-efficient browser automation. Instead of full DOM selectors or raw accessibility trees, snapshot returns compact element references.

## How Refs Work

Run `snapshot -i` to get interactive elements with their refs:

```bash
agent-browser --session s1 snapshot -i
```

**Example output:**
```
@e1 [heading] "Example Domain" [level=1]
@e2 [button] "Submit"
@e3 [input type="email"] placeholder="Email address"
@e4 [link] "Learn more"
```

Each `@eN` ref uniquely identifies an element on the current page. Use refs directly in subsequent commands:

```bash
agent-browser --session s1 click @e2           # Click the Submit button
agent-browser --session s1 fill @e3 "a@b.com"  # Fill the email input
agent-browser --session s1 get text @e1        # Get heading text
```

## Why Refs?

Refs use ~93% fewer tokens per interaction compared to raw Playwright accessibility trees or DOM snapshots. The accessibility tree is compact, refs are tiny, and Claude can automate browsers without burning through context window.

## Snapshot Options

Control what the snapshot includes to further reduce token usage:

```bash
agent-browser --session s1 snapshot              # Full accessibility tree (most complete)
agent-browser --session s1 snapshot -i           # Interactive elements only (recommended)
agent-browser --session s1 snapshot -i -C        # Also include cursor-interactive elements
agent-browser --session s1 snapshot -c           # Compact (remove empty structural elements)
agent-browser --session s1 snapshot -d 3         # Limit depth to 3 levels
agent-browser --session s1 snapshot -s "#main"   # Scope to CSS selector
```

**Recommendation**: Use `snapshot -i` for most tasks. Add `-C` when the page uses custom clickable elements (divs, spans with onclick or cursor:pointer).

## Ref Lifecycle

**Refs are invalidated when the page changes.** Always re-snapshot after:
- Navigation (clicking a link, form submit, `open` command)
- DOM changes (dynamic content loading, modal dialogs appearing)
- Page reload

```bash
agent-browser --session s1 click @e4         # Navigates to new page
agent-browser --session s1 snapshot -i       # Get fresh refs
agent-browser --session s1 click @e1         # Use new refs (NOT old ones)
```

Using a stale ref after navigation will fail or interact with the wrong element.

## Annotated Screenshots

For visual context alongside text snapshots, use `screenshot --annotate` to overlay numbered labels on interactive elements:

```bash
agent-browser --session s1 screenshot --annotate /tmp/page.png
# Output:
#   [1] @e1 button "Submit"
#   [2] @e2 link "Home"
#   [3] @e3 textbox "Email"
agent-browser --session s1 click @e2
```

Annotated screenshots also cache refs, so you can interact with elements immediately after. Useful when the text snapshot is ambiguous.

## JSON Output

For programmatic parsing:

```bash
agent-browser --session s1 snapshot --json
```

Returns structured JSON with element refs, roles, names, and attributes.

## Fallback Selectors

When refs are unavailable or stale, fall back to standard selectors:

| Strategy | Example | When to Use |
|----------|---------|-------------|
| Snapshot ref | `@e1` | After snapshot — most reliable |
| CSS selector | `button.submit` | When you know the structure |
| ID | `#login-button` | When ID is available |
| Semantic find | `find role "button" click` | By ARIA role/text/testid |

## Troubleshooting

**"Element not found" after clicking a link:**
- The page navigated; old refs are invalid
- Re-run `snapshot -i` to get fresh refs

**Missing interactive elements in snapshot:**
- Try `snapshot -i -C` to include cursor-interactive elements
- Some apps use non-standard clickable elements (divs with onclick)

**Snapshot too large:**
- Use `-d 3` to limit depth
- Use `-s "#main"` to scope to a specific section
- Use `-i` to show only interactive elements

**Complex pages with dynamic content:**
- Use `wait --load networkidle` before snapshotting
- Wait for specific elements with `wait <selector>` first
