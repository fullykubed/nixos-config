/**
 * Unix socket server for dev-browser IPC
 */

import type {
  JsonRpcRequest,
  JsonRpcResponse,
  JsonRpcSuccessResponse,
  JsonRpcErrorResponse,
  RpcHandler,
} from "./types";
import type { IdleTimeout } from "./timeout";
import { unlink } from "node:fs/promises";
import type { ServerWebSocket } from "bun";

/**
 * Socket connection data tracker for partial message buffering
 */
interface SocketData {
  buffer: string;
}

/**
 * JSON-RPC error codes
 */
const RPC_ERROR_CODES = {
  PARSE_ERROR: -32700,
  INVALID_REQUEST: -32600,
  METHOD_NOT_FOUND: -32601,
  INTERNAL_ERROR: -32603,
} as const;

/**
 * Creates a Unix socket server that handles JSON-RPC style commands
 *
 * @param socketPath - Path to Unix socket file (e.g., /tmp/dev-browser-<session>.sock)
 * @param handlers - Map of method names to handler functions
 * @param idleTimeout - Optional idle timeout tracker to reset on activity
 * @returns Bun socket listener
 */
export function createSocketServer(
  socketPath: string,
  handlers: Map<string, RpcHandler>,
  idleTimeout?: IdleTimeout
) {
  console.log(`Starting dev-browser socket server at ${socketPath}`);

  const server = Bun.listen<SocketData>({
    unix: socketPath,
    socket: {
      open(socket) {
        console.log(`Client connected to ${socketPath}`);
        // Initialize buffer for this connection
        socket.data = { buffer: "" };
      },

      data(socket, data) {
        // Reset idle timeout on any activity
        if (idleTimeout) {
          idleTimeout.touch();
        }

        // Convert incoming data to string and append to buffer
        const chunk = data.toString();
        socket.data.buffer += chunk;

        // Process all complete messages (newline-delimited)
        const lines = socket.data.buffer.split("\n");
        // Keep the last incomplete line in the buffer
        socket.data.buffer = lines.pop() || "";

        // Process each complete line
        for (const line of lines) {
          if (line.trim()) {
            handleMessage(socket, line, handlers);
          }
        }
      },

      close(socket) {
        console.log("Client disconnected");
      },

      error(socket, error) {
        console.error("Socket error:", error);
      },
    },
  });

  return server;
}

/**
 * Handles a single JSON-RPC message
 */
async function handleMessage(
  socket: ServerWebSocket<SocketData>,
  message: string,
  handlers: Map<string, RpcHandler>
) {
  let request: JsonRpcRequest;

  // Parse JSON
  try {
    request = JSON.parse(message);
  } catch (error) {
    const response: JsonRpcErrorResponse = {
      error: {
        code: RPC_ERROR_CODES.PARSE_ERROR,
        message: "Parse error: Invalid JSON",
      },
      id: 0,
    };
    socket.write(JSON.stringify(response) + "\n");
    return;
  }

  // Validate request format
  if (
    typeof request !== "object" ||
    request === null ||
    typeof request.method !== "string" ||
    typeof request.id !== "number"
  ) {
    const response: JsonRpcErrorResponse = {
      error: {
        code: RPC_ERROR_CODES.INVALID_REQUEST,
        message: "Invalid Request: Missing required fields",
      },
      id: request?.id ?? 0,
    };
    socket.write(JSON.stringify(response) + "\n");
    return;
  }

  // Check if method exists
  const handler = handlers.get(request.method);
  if (!handler) {
    const response: JsonRpcErrorResponse = {
      error: {
        code: RPC_ERROR_CODES.METHOD_NOT_FOUND,
        message: `Method not found: ${request.method}`,
      },
      id: request.id,
    };
    socket.write(JSON.stringify(response) + "\n");
    return;
  }

  // Execute handler
  try {
    const result = await handler(request.params);
    const response: JsonRpcSuccessResponse = {
      result,
      id: request.id,
    };
    socket.write(JSON.stringify(response) + "\n");
  } catch (error) {
    const response: JsonRpcErrorResponse = {
      error: {
        code: RPC_ERROR_CODES.INTERNAL_ERROR,
        message: error instanceof Error ? error.message : "Internal error",
      },
      id: request.id,
    };
    socket.write(JSON.stringify(response) + "\n");
  }
}

/**
 * Cleans up socket file on shutdown
 */
export async function cleanupSocket(socketPath: string) {
  try {
    await unlink(socketPath);
    console.log(`Removed socket file: ${socketPath}`);
  } catch (error) {
    // Ignore error if file doesn't exist
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
      console.error(`Failed to remove socket file: ${error}`);
    }
  }
}
