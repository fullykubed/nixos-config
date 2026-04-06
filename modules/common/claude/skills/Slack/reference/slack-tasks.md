# Slack Tasks Reference

Common Slack operations using `agent-browser` browser automation.

## Setup: Connect to Slack

```bash
# Connect to existing Slack session (fastest)
agent-browser connect 9222

# Or open Slack if not already running
agent-browser open https://app.slack.com

# Take initial snapshot to see current state
agent-browser snapshot -i
```

## Checking Unread Messages

```bash
# Connect to Slack
agent-browser connect 9222
agent-browser snapshot -i

# Option 1: Navigate to Activity tab (shows all unreads in one view)
agent-browser click @e14   # Activity tab ref (varies by session)
agent-browser wait 1000
agent-browser screenshot activity-unreads.png

# Option 2: Check DMs tab
agent-browser click @e13   # DMs tab
agent-browser screenshot dms.png

# Option 3: Expand "More unreads" in sidebar
agent-browser click @e21   # More unreads button
agent-browser wait 500
agent-browser snapshot -i
agent-browser screenshot expanded-unreads.png
```

Look for:
- "More unreads" button near the top of the sidebar
- Channel names shown in bold or with numeric badges
- Activity tab showing unread count

## Navigating to a Channel

```bash
agent-browser snapshot -i

# Find the channel name in the treeitem list and click its ref
agent-browser click @e94   # Example: engineering channel ref
agent-browser wait --load networkidle
agent-browser screenshot channel.png
```

## Reading Channel Messages

```bash
# After navigating to a channel
agent-browser snapshot -i

# Scroll through messages
agent-browser scroll down 500
agent-browser screenshot channel-messages.png

# Get full-page screenshot
agent-browser screenshot --full channel-full.png

# Get JSON snapshot to parse message content
agent-browser snapshot --json > channel-snapshot.json
```

## Sending a Message

```bash
# Navigate to target channel
agent-browser click @e_channel_ref
agent-browser wait 1000
agent-browser snapshot -i

# Find the message input (usually at the bottom)
agent-browser click @e_message_input
agent-browser fill @e_message_input "Your message here"
agent-browser press Enter
agent-browser wait 500
agent-browser screenshot message-sent.png
```

## Searching Conversations

```bash
# Open search
agent-browser snapshot -i
agent-browser click @e5    # Search button (typical ref)

# Enter search query
agent-browser fill @e_search_input "your search terms"
agent-browser press Enter
agent-browser wait --load networkidle
agent-browser screenshot search-results.png

# Filter options (after search loads):
# - Add "in:#channel-name" to scope to a channel
# - Add "from:@username" to filter by sender
# - Add "before:YYYY-MM-DD" or "after:YYYY-MM-DD" for date filtering
```

## Extracting Channel List

```bash
# Get full accessibility tree as JSON
agent-browser snapshot --json > slack-snapshot.json

# Channel names appear as treeitem elements in the sidebar
# Look for:
# - level=2 treeitems (sub-items under section headers)
# - name field contains the channel name
# - Elements with badge counts have unread messages
```

## Viewing Threads

```bash
# From within a channel, click a message to open its thread
agent-browser snapshot -i
agent-browser click @e_message_ref   # Click a message ref

agent-browser wait 1000
agent-browser snapshot -i            # Refs update in thread panel
agent-browser screenshot thread.png
```

## Checking Pinned Messages

```bash
# Navigate to a channel
agent-browser click @e_channel_ref
agent-browser wait 1000

# Click the Pins tab
agent-browser snapshot -i
agent-browser click @e_pins_tab      # Look for "Pins" tab ref
agent-browser wait 500
agent-browser screenshot pins.png
```

## Viewing Channel Info (Members, Description)

```bash
# Open a channel
agent-browser click @e_channel_ref
agent-browser wait 1000

# Click the channel name or info button at the top
agent-browser snapshot -i
agent-browser click @e_channel_name   # Channel header ref
agent-browser wait 500
agent-browser screenshot channel-info.png
```

## Capturing Evidence

```bash
# Standard screenshot
agent-browser screenshot output.png

# Annotated screenshot (shows element ref numbers overlaid)
agent-browser screenshot --annotate annotated.png

# Full-page screenshot
agent-browser screenshot --full full-page.png

# Get current URL
agent-browser get url

# Get page title
agent-browser get title
```

## Extracting Structured Data

```bash
# Full JSON accessibility tree
agent-browser snapshot --json > output.json

# Parse for specific element types:
# - "treeitem" elements = channels/DMs in sidebar
# - "listitem" elements = messages
# - "link" with time info = timestamps (found in message URLs)
# - "button" with user info = user names

# Count unread channels
agent-browser snapshot -i | grep -c "treeitem"
```

## Sidebar Navigation Patterns

The Slack sidebar contains sections that can be expanded/collapsed:

```
Threads
Huddles
Drafts & sent
Directories
[Starred] (section header)
  channel-name (treeitem)
[Channels] (section header)
  channel-name (treeitem)
[Direct Messages] (section header)
  user-name (treeitem)
Apps
[More unreads] (button)
```

To scroll within the sidebar when the channel list is long:

```bash
agent-browser scroll down 300 --selector ".p-sidebar"
```

## Timing and Reliability

```bash
# Wait for a fixed duration (milliseconds)
agent-browser wait 1000

# Wait for network to settle after navigation
agent-browser wait --load networkidle

# If element not found, try including cursor-interactive elements
agent-browser snapshot -i -C
```

## Debugging

```bash
# Check browser console for JavaScript errors
agent-browser console
agent-browser errors

# Get current page URL to verify you are in the right place
agent-browser get url

# View raw page state
agent-browser get title
agent-browser screenshot debug-state.png
```

## Limitations

- **No Slack API**: This uses browser automation only. No OAuth tokens or bot credentials required or supported.
- **Workspace-specific**: Automation runs against your own signed-in workspace.
- **Session-specific**: State (snapshots, refs) is tied to the current browser session.
- **Rate limiting**: Slack may throttle rapid interactions. Add `agent-browser wait 1000` between fast actions.
- **Dynamic refs**: Element refs (`@e1`, `@e2`, etc.) change after page navigation — always re-snapshot.
