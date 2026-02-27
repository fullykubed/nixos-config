/**
 * Session management for dev-browser
 * Handles starting, stopping, and checking server status
 */

import { existsSync } from "fs";
import { connectToServer } from "./client";

/**
 * Get the Unix socket path for a given session ID
 */
export function getSocketPath(sessionId: string): string {
  return `/tmp/dev-browser-${sessionId}.sock`;
}

/**
 * Check if server is running for the given session
 */
export function isServerRunning(sessionId: string): boolean {
  return existsSync(getSocketPath(sessionId));
}

/**
 * Start the dev-browser server for the given session
 * Spawns server in background and waits for it to be ready
 */
export async function startServer(sessionId: string): Promise<void> {
  if (isServerRunning(sessionId)) {
    console.log(`Server already running for session: ${sessionId}`);
    return;
  }

  const serverPath = import.meta.dir + "/server.ts";
  const proc = Bun.spawn({
    cmd: ["bun", "run", serverPath, sessionId],
    stdout: "inherit",
    stderr: "inherit",
    stdin: "ignore",
  });

  // Wait for socket to appear (server ready)
  const socketPath = getSocketPath(sessionId);
  const maxWait = 10000; // 10 seconds
  const start = Date.now();

  while (!existsSync(socketPath)) {
    if (Date.now() - start > maxWait) {
      throw new Error("Server failed to start within timeout");
    }
    await Bun.sleep(100);
  }

  console.log(`Server started with session: ${sessionId}`);
}

/**
 * Stop the dev-browser server for the given session
 * Sends shutdown signal and waits for server to terminate
 */
export async function stopServer(sessionId: string): Promise<void> {
  if (!isServerRunning(sessionId)) {
    console.log(`Server not running for session: ${sessionId}`);
    return;
  }

  try {
    const client = await connectToServer(sessionId);
    await client.send({ method: "shutdown", params: {}, id: 1 });
    client.close();
  } catch (error) {
    console.error("Error sending shutdown signal:", error);
    throw error;
  }

  // Wait for socket to disappear (server terminated)
  const socketPath = getSocketPath(sessionId);
  const maxWait = 5000; // 5 seconds
  const start = Date.now();

  while (existsSync(socketPath)) {
    if (Date.now() - start > maxWait) {
      console.warn("Server did not shut down within timeout");
      break;
    }
    await Bun.sleep(100);
  }

  console.log(`Server stopped for session: ${sessionId}`);
}
