/**
 * Socket client for communicating with dev-browser server
 */

import type { JsonRpcRequest, JsonRpcResponse } from "./types";
import { getSocketPath } from "./session";

/**
 * Client for sending commands to dev-browser server
 */
export class DevBrowserClient {
  private socket: ReturnType<typeof Bun.connect>;
  private messageBuffer: string = "";
  private pendingResponses: Map<
    number,
    {
      resolve: (value: unknown) => void;
      reject: (error: Error) => void;
    }
  > = new Map();
  private nextId = 1;

  constructor(socket: ReturnType<typeof Bun.connect>) {
    this.socket = socket;
  }

  /**
   * Send a JSON-RPC request to the server
   */
  async send(request: Omit<JsonRpcRequest, "id">): Promise<unknown> {
    const id = this.nextId++;
    const fullRequest: JsonRpcRequest = { ...request, id };

    return new Promise((resolve, reject) => {
      this.pendingResponses.set(id, { resolve, reject });

      const message = JSON.stringify(fullRequest) + "\n";
      this.socket.write(message);
    });
  }

  /**
   * Handle incoming data from server
   */
  private handleData(data: Buffer) {
    // Append to buffer
    this.messageBuffer += data.toString();

    // Process all complete messages (newline-delimited)
    const lines = this.messageBuffer.split("\n");
    // Keep the last incomplete line in the buffer
    this.messageBuffer = lines.pop() || "";

    // Process each complete line
    for (const line of lines) {
      if (line.trim()) {
        this.handleMessage(line);
      }
    }
  }

  /**
   * Handle a single JSON-RPC response message
   */
  private handleMessage(message: string) {
    try {
      const response: JsonRpcResponse = JSON.parse(message);

      const pending = this.pendingResponses.get(response.id);
      if (!pending) {
        console.error(`Received response for unknown request ID: ${response.id}`);
        return;
      }

      this.pendingResponses.delete(response.id);

      if ("error" in response) {
        pending.reject(new Error(response.error.message));
      } else {
        pending.resolve(response.result);
      }
    } catch (error) {
      console.error("Failed to parse server response:", error);
    }
  }

  /**
   * Close the client connection
   */
  close() {
    this.socket.end();
  }
}

/**
 * Connect to the dev-browser server for the given session
 */
export async function connectToServer(
  sessionId: string
): Promise<DevBrowserClient> {
  const socketPath = getSocketPath(sessionId);

  return new Promise((resolve, reject) => {
    const socket = Bun.connect({
      unix: socketPath,
      socket: {
        data(socket, data) {
          // Forward data to client instance
          const client = (socket as any).client as DevBrowserClient;
          client["handleData"](data);
        },
        open(socket) {
          const client = new DevBrowserClient(socket);
          // Store client instance on socket for data handler
          (socket as any).client = client;
          resolve(client);
        },
        error(socket, error) {
          reject(error);
        },
        close(socket) {
          // Connection closed
        },
      },
    });
  });
}
