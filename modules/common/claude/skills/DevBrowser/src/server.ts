/**
 * dev-browser server - manages persistent Playwright browser sessions
 */

import { BrowserManager } from "./browser";
import { registerHandlers } from "./handlers";
import { cleanupSocket, createSocketServer } from "./socket";
import { IdleTimeout } from "./timeout";
import type { RpcHandler } from "./types";

// Get session ID from command line argument
const sessionId = process.argv[2];
if (!sessionId) {
  console.error("Usage: bun run src/server.ts <session-id>");
  process.exit(1);
}

console.log(`Starting dev-browser server for session: ${sessionId}`);

const socketPath = `/tmp/dev-browser-${sessionId}.sock`;

// Configure idle timeout (default 30 minutes)
const timeoutMs = parseInt(process.env.DEV_BROWSER_TIMEOUT_MS ?? "1800000");
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

async function gracefulShutdown(): Promise<void> {
  await browser.close();
  server.stop();
  await cleanupSocket(socketPath);
  idleTimeout.stop();
  process.exit(0);
}

// Initialize idle timeout handler (must be created before socket server)
const idleTimeout = new IdleTimeout(timeoutMs, () => {
  console.log("Initiating graceful shutdown due to idle timeout");
  void gracefulShutdown();
});

// Register RPC method handlers
const handlers = new Map<string, RpcHandler>();

// Register browser operation handlers
registerHandlers(handlers, browser);

// Additional utility handlers
handlers.set("ping", (_params) => {
  return Promise.resolve({ pong: true });
});

handlers.set("echo", (params) => {
  return Promise.resolve(params);
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
process.on("SIGINT", () => {
  console.log("\nReceived SIGINT, shutting down gracefully");
  void gracefulShutdown();
});

process.on("SIGTERM", () => {
  console.log("\nReceived SIGTERM, shutting down gracefully");
  void gracefulShutdown();
});
