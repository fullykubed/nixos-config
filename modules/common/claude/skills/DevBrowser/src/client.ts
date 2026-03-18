/**
 * Socket client for communicating with dev-browser server
 */

import { getSocketPath } from "./session";
import type { JsonRpcRequest, JsonRpcResponse } from "./types";

/**
 * Socket data used to back-reference the DevBrowserClient instance
 */
interface ClientSocketData {
  client: DevBrowserClient;
}

/**
 * Client for sending commands to dev-browser server
 */
export class DevBrowserClient {
  private socket: Bun.Socket<ClientSocketData>;
  private messageBuffer: string = "";
  private pendingResponses: Map<
    number,
    {
      resolve: (value: unknown) => void;
      reject: (error: Error) => void;
    }
  > = new Map();
  private nextId = 1;

  constructor(socket: Bun.Socket<ClientSocketData>) {
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
  handleData(data: Buffer) {
    // Append to buffer
    this.messageBuffer += data.toString();

    // Process all complete messages (newline-delimited)
    const lines = this.messageBuffer.split("\n");
    // Keep the last incomplete line in the buffer
    this.messageBuffer = lines.pop() ?? "";

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
      const response = JSON.parse(message) as JsonRpcResponse;

      const pending = this.pendingResponses.get(response.id);
      if (!pending) {
        console.error(`Received response for unknown request ID: ${String(response.id)}`);
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
    void Bun.connect<ClientSocketData>({
      unix: socketPath,
      socket: {
        data(socket, data) {
          socket.data.client.handleData(data);
        },
        open(socket) {
          const client = new DevBrowserClient(socket);
          socket.data = { client };
          resolve(client);
        },
        error(_socket, error) {
          reject(error);
        },
        close(_socket) {
          // Connection closed
        },
      },
    });
  });
}
