# BrowseWeb Workflow

This workflow guides you through interacting with web pages for testing, verification, and data extraction.

## Workflow Steps

### 1. Initialize Session

Start a browser session (or reuse an existing one):

```bash
dev-browser start --session browse-session
```

If the session already exists, the command returns immediately.

### 2. Navigate to Target

Open the target URL:

```bash
dev-browser navigate --session browse-session "https://example.com"
```

**Output:**
```json
{
  "url": "https://example.com/",
  "title": "Example Domain"
}
```

### 3. Understand Page Structure

Get an AI-optimized snapshot of the page:

```bash
dev-browser snapshot --session browse-session
```

**Output:**
```json
{
  "url": "https://example.com/",
  "title": "Example Domain",
  "snapshot": "- document\n  - heading @e1 \"Example Domain\"\n  - paragraph \"This domain is...\"\n  - link @e2 \"More information...\"\n",
  "locators": {
    "@e1": "Example Domain",
    "@e2": "More information..."
  }
}
```

**Understanding the Snapshot:**
- Interactive elements have locators (@e1, @e2, etc.)
- Use these locators as selectors for click/type
- The snapshot shows the accessibility tree, not raw HTML

### 4. Interact with Page

**Click an element:**
```bash
dev-browser click --session browse-session "@e2"
# Or use CSS selector:
dev-browser click --session browse-session "a[href*='iana']"
```

**Fill a form:**
```bash
dev-browser type --session browse-session "input[name='email']" "user@example.com"
dev-browser click --session browse-session "button[type='submit']"
```

**Execute JavaScript:**
```bash
dev-browser eval --session browse-session "document.title"
```

### 5. Wait for Dynamic Content

If the page loads content dynamically:

```bash
dev-browser wait --session browse-session ".results-container" --timeout 10000
```

This waits up to 10 seconds for the element to appear.

### 6. Capture Evidence

**Take a screenshot:**
```bash
# Save to file
dev-browser screenshot --session browse-session --path /tmp/page.png

# Or get base64 for inline display
dev-browser screenshot --session browse-session
```

### 7. Clean Up (Optional)

When done, stop the session:

```bash
dev-browser stop --session browse-session
```

Note: Sessions auto-terminate after 30 minutes of inactivity.

## Common Patterns

### Login Flow

```bash
dev-browser navigate --session s1 "https://app.example.com/login"
dev-browser snapshot --session s1
dev-browser type --session s1 "input[name='email']" "user@example.com"
dev-browser type --session s1 "input[name='password']" "secret123"
dev-browser click --session s1 "button[type='submit']"
dev-browser wait --session s1 ".dashboard"
dev-browser snapshot --session s1
```

### Form Verification

```bash
dev-browser navigate --session s1 "https://example.com/form"
dev-browser type --session s1 "#name" "Test User"
dev-browser type --session s1 "#email" "test@example.com"
dev-browser click --session s1 "button[type='submit']"
dev-browser wait --session s1 ".success-message"
dev-browser snapshot --session s1  # Verify success state
```

### Data Extraction

```bash
dev-browser navigate --session s1 "https://example.com/data"
dev-browser wait --session s1 ".data-table"
dev-browser eval --session s1 "JSON.stringify([...document.querySelectorAll('.data-row')].map(r => r.textContent))"
```

## Selector Strategies

| Strategy | Example | When to Use |
|----------|---------|-------------|
| Locator | `@e1` | From snapshot, most reliable |
| CSS | `button.submit` | When you know the structure |
| ID | `#login-button` | When ID is available |
| Text | `text=Submit` | For visible text matching |
| XPath | `//button[@type='submit']` | Complex queries |

## Error Handling

**Element not found:**
- Re-run `snapshot` to see current page state
- Check if page has navigated or changed
- Try a different selector strategy

**Timeout:**
- Increase timeout with `--timeout` flag
- Check if element is inside iframe
- Verify the page is fully loaded

**Navigation failed:**
- Check URL is correct
- Verify network connectivity
- Look for redirects in response
