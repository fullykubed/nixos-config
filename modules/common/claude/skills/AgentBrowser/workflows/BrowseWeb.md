# BrowseWeb Workflow

This workflow guides you through interacting with web pages for testing, verification, and data extraction using agent-browser.

## Workflow Steps

### 1. Navigate to Target

Open the target URL (the daemon starts automatically on first use):

```bash
agent-browser --session browse-session open "https://example.com"
```

**Output:**
```
Navigated to https://example.com/
```

For slow pages, wait for full load:

```bash
agent-browser --session browse-session open "https://example.com" && agent-browser --session browse-session wait --load networkidle
```

### 2. Understand Page Structure

Get an interactive snapshot of the page to discover clickable elements:

```bash
agent-browser --session browse-session snapshot -i
```

**Output:**
```
@e1 [heading] "Example Domain" [level=1]
@e2 [link] "More information..."
@e3 [button] "Submit"
@e4 [input type="email"] placeholder="Email address"
```

**Understanding the Snapshot:**
- Interactive elements have locators (@e1, @e2, etc.)
- Use these locators as selectors for click/fill — they are the most reliable
- The snapshot shows the accessibility tree, not raw HTML
- Refs are invalidated after navigation; always re-snapshot after page changes

### 3. Interact with Page

**Click an element using a ref:**
```bash
agent-browser --session browse-session click @e2
```

**Fill a form using refs:**
```bash
agent-browser --session browse-session fill @e4 "user@example.com"
agent-browser --session browse-session click @e3
```

**Fill using CSS selector (when ref is unavailable):**
```bash
agent-browser --session browse-session fill "input[name='email']" "user@example.com"
agent-browser --session browse-session click "button[type='submit']"
```

**Execute JavaScript:**
```bash
agent-browser --session browse-session eval "document.title"
```

### 4. Wait for Dynamic Content

If the page loads content dynamically:

```bash
agent-browser --session browse-session wait ".results-container"
```

Wait for text to appear:

```bash
agent-browser --session browse-session wait --text "Welcome"
```

Wait for network to settle (best for slow pages):

```bash
agent-browser --session browse-session wait --load networkidle
```

### 5. Capture Evidence

**Take a screenshot saved to file:**
```bash
agent-browser --session browse-session screenshot /tmp/page.png
```

**Take an annotated screenshot with numbered element labels:**
```bash
agent-browser --session browse-session screenshot --annotate /tmp/page-annotated.png
```

**Re-snapshot to verify page state after interactions:**
```bash
agent-browser --session browse-session snapshot -i
```

### 6. Clean Up

When done, close the session:

```bash
agent-browser --session browse-session close
```

Note: Sessions auto-terminate after 30 minutes of inactivity.

## Common Patterns

### Login Flow

```bash
agent-browser --session s1 open "https://app.example.com/login"
agent-browser --session s1 snapshot -i
agent-browser --session s1 fill @e1 "user@example.com"
agent-browser --session s1 fill @e2 "secret123"
agent-browser --session s1 click @e3
agent-browser --session s1 wait ".dashboard"
agent-browser --session s1 snapshot -i
```

### Form Verification

```bash
agent-browser --session s1 open "https://example.com/form"
agent-browser --session s1 snapshot -i
agent-browser --session s1 fill @e1 "Test User"
agent-browser --session s1 fill @e2 "test@example.com"
agent-browser --session s1 click @e3
agent-browser --session s1 wait --text "Success"
agent-browser --session s1 snapshot -i  # Verify success state
```

### Data Extraction

```bash
agent-browser --session s1 open "https://example.com/data"
agent-browser --session s1 wait ".data-table"
agent-browser --session s1 eval "JSON.stringify([...document.querySelectorAll('.data-row')].map(r => r.textContent))"
```

### Screenshot Capture

```bash
agent-browser --session s1 open "https://example.com"
agent-browser --session s1 wait --load networkidle
agent-browser --session s1 screenshot --annotate /tmp/page.png
```

## Selector Strategies

| Strategy | Example | When to Use |
|----------|---------|-------------|
| Snapshot ref | `@e1` | From snapshot, most reliable |
| CSS | `button.submit` | When you know the structure |
| ID | `#login-button` | When ID is available |
| Text | `--text "Submit"` | For visible text matching (wait command) |

## Error Handling

**Element not found:**
- Re-run `snapshot -i` to see current page state
- Check if page has navigated or changed
- Try a different selector strategy

**Timeout:**
- Use `wait --load networkidle` before interacting with slow pages
- Check if element is inside an iframe
- Verify the page is fully loaded

**Navigation failed:**
- Check URL is correct
- Verify network connectivity
- Look for redirects in response
