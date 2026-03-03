/**
 * Shared type definitions for dev-browser
 */

/**
 * JSON-RPC request format
 */
export interface JsonRpcRequest {
  method: string;
  params?: Record<string, unknown>;
  id: number;
}

/**
 * JSON-RPC success response format
 */
export interface JsonRpcSuccessResponse {
  result: unknown;
  id: number;
}

/**
 * JSON-RPC error response format
 */
export interface JsonRpcErrorResponse {
  error: {
    code: number;
    message: string;
  };
  id: number;
}

/**
 * JSON-RPC response type (success or error)
 */
export type JsonRpcResponse = JsonRpcSuccessResponse | JsonRpcErrorResponse;

/**
 * Handler function type for JSON-RPC methods
 */
export type RpcHandler = (params: unknown) => Promise<unknown>;
