# src/

TypeScript source for the DevBrowser CLI and WebSocket server/client.

- `cli.ts` — CLI argument parsing and command routing for browser operations.
- `browser.ts` — Core headless Chromium initialization and lifecycle management.
- `server.ts` — WebSocket server hosting browser sessions with auto-cleanup.
- `client.ts` — WebSocket client for communicating with the browser server.
- `socket.ts` — WebSocket protocol implementation for server/client communication.
- `session.ts` — Per-session state management (cookies, localStorage, JavaScript context).
- `commands.ts` — Implementation of browser commands (navigate, click, type, wait, eval).
- `handlers.ts` — Event handlers for browser lifecycle, navigation, and error conditions.
- `snapshot.ts` — DOM snapshot generation optimized for AI understanding.
- `timeout.ts` — Inactivity tracking; auto-terminates idle sessions after 30 minutes.
- `types.ts` — TypeScript type definitions for browser commands, responses, and session state.
