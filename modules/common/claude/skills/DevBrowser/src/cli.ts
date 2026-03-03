#!/usr/bin/env bun

/**
 * dev-browser CLI - command-line interface for browser automation
 */

import { startServer, stopServer, isServerRunning } from "./session";
import { connectToServer } from "./client";
import {
  navigate,
  click,
  type as typeCommand,
  screenshot,
  evaluate,
  wait,
  snapshot,
  status,
} from "./commands";

// Parse command-line arguments
const args = process.argv.slice(2);
const command = args[0];

// Parse --session flag
let sessionId = crypto.randomUUID();
const sessionIdx = args.indexOf("--session");
if (sessionIdx !== -1 && args[sessionIdx + 1]) {
  sessionId = args[sessionIdx + 1];
}

/**
 * Main CLI entry point
 */
async function main() {
  if (!command) {
    console.error("Usage: dev-browser <command> [--session <id>] [args...]");
    console.error("\nSession Commands:");
    console.error("  start               Start the browser server");
    console.error("  stop                Stop the browser server");
    console.error("\nBrowser Commands:");
    console.error("  navigate <url>      Navigate to a URL");
    console.error("  click <selector>    Click an element");
    console.error("  type <selector> <text>  Type text into an element");
    console.error("  screenshot [--path <file>]  Take a screenshot");
    console.error("  eval <script>       Execute JavaScript");
    console.error("  wait <selector> [--timeout <ms>]  Wait for element");
    console.error("  snapshot            Get AI-optimized page snapshot");
    console.error("  status              Get server status");
    console.error("\nOptions:");
    console.error("  --session <id>      Session ID (default: auto-generated UUID)");
    process.exit(1);
  }

  switch (command) {
    case "start":
      await startServer(sessionId);
      break;

    case "stop":
      await stopServer(sessionId);
      break;

    default:
      // Auto-start server if not running for other commands
      if (!isServerRunning(sessionId)) {
        console.log("Server not running, auto-starting...");
        await startServer(sessionId);
      }

      // Connect to server for command execution
      const client = await connectToServer(sessionId);

      try {
        // Dispatch to command handlers
        switch (command) {
          case "navigate":
            if (!args[1]) {
              console.error("Error: navigate requires a URL argument");
              process.exit(1);
            }
            await navigate(client, args[1]);
            break;

          case "click":
            if (!args[1]) {
              console.error("Error: click requires a selector argument");
              process.exit(1);
            }
            await click(client, args[1]);
            break;

          case "type":
            if (!args[1] || !args[2]) {
              console.error("Error: type requires selector and text arguments");
              process.exit(1);
            }
            await typeCommand(client, args[1], args[2]);
            break;

          case "screenshot": {
            const pathIdx = args.indexOf("--path");
            const path = pathIdx !== -1 ? args[pathIdx + 1] : undefined;
            await screenshot(client, path);
            break;
          }

          case "eval":
            if (!args[1]) {
              console.error("Error: eval requires a script argument");
              process.exit(1);
            }
            await evaluate(client, args[1]);
            break;

          case "wait": {
            if (!args[1]) {
              console.error("Error: wait requires a selector argument");
              process.exit(1);
            }
            const timeoutIdx = args.indexOf("--timeout");
            const timeout =
              timeoutIdx !== -1 ? parseInt(args[timeoutIdx + 1]) : undefined;
            await wait(client, args[1], timeout);
            break;
          }

          case "snapshot":
            await snapshot(client);
            break;

          case "status":
            await status(client);
            break;

          default:
            console.error(`Unknown command: ${command}`);
            console.error(
              "Available commands: start, stop, navigate, click, type, screenshot, eval, wait, snapshot, status"
            );
            process.exit(1);
        }
      } finally {
        client.close();
      }
  }
}

main().catch((error) => {
  console.error("Error:", error.message);
  process.exit(1);
});
