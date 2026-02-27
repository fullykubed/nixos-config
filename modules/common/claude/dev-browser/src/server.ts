/**
 * dev-browser server - manages persistent Playwright browser sessions
 */

import { IdleTimeout } from "./timeout";
import { createSocketServer, cleanupSocket } from "./socket";
import type { RpcHandler } from "./types";
import { BrowserManager } from "./browser";
import { registerHandlers } from "./handlers";

// Get session ID from command line argument
const sessionId = process.argv[2];
if (!sessionId) {
  console.error("Usage: bun run src/server.ts <session-id>");
  process.exit(1);
}

console.log(`Starting dev-browser server for session: ${sessionId}`);

const socketPath = `/tmp/dev-browser-${sessionId}.sock`;

// Configure idle timeout (default 30 minutes)
const timeoutMs = parseInt(process.env.DEV_BROWSER_TIMEOUT_MS || "1800000");
console.log(`Idle timeout configured: ${timeoutMs}ms (${timeoutMs / 60000} minutes)`);

// Initialize browser manager
const browser = new BrowserManager(sessionId);

// Launch browser
try {
  await browser.launch();
  console.log("Browser launched successfully");
} catch (error) {
  console.error("Failed to launch browser:", error);
  process.exit(1);
}

// Initialize idle timeout handler (must be created before socket server)
const idleTimeout = new IdleTimeout(timeoutMs, async () => {
  console.log("Initiating graceful shutdown due to idle timeout");

  // Close browser
  await browser.close();

  // Stop socket listener
  server.stop();
  await cleanupSocket(socketPath);

  // Clean up interval and exit
  idleTimeout.stop();
  process.exit(0);
});

// Register RPC method handlers
const handlers = new Map<string, RpcHandler>();

// Register browser operation handlers
registerHandlers(handlers, browser);

// Additional utility handlers
handlers.set("ping", async (params) => {
  return { pong: true };
});

handlers.set("echo", async (params) => {
  return params;
});

// Create socket server with idle timeout integration
const server = createSocketServer(socketPath, handlers, idleTimeout);

// Start monitoring for idle timeout
idleTimeout.start();

console.log(`dev-browser server ready`);
console.log(`Socket: ${socketPath}`);
console.log(`Idle timeout monitoring started`);

// Note: idleTimeout.touch() is called within socket.ts data handler to reset timeout on activity

// Keep process alive until timeout or manual termination
process.on("SIGINT", async () => {
  console.log("\nReceived SIGINT, shutting down gracefully");
  idleTimeout.stop();
  await browser.close();
  server.stop();
  await cleanupSocket(socketPath);
  process.exit(0);
});

process.on("SIGTERM", async () => {
  console.log("\nReceived SIGTERM, shutting down gracefully");
  idleTimeout.stop();
  await browser.close();
  server.stop();
  await cleanupSocket(socketPath);
  process.exit(0);
});
