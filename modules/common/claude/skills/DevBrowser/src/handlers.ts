/**
 * RPC method handlers for browser operations
 */

import type { BrowserManager } from "./browser";
import { generateSnapshot } from "./snapshot";
import type { RpcHandler } from "./types";

/**
 * Narrow an unknown value to a plain object, or null
 */
function asObject(params: unknown): Record<string, unknown> | null {
  if (typeof params === "object" && params !== null && !Array.isArray(params)) {
    return params as Record<string, unknown>;
  }
  return null;
}

/**
 * Register all RPC handlers for browser operations
 */
export function registerHandlers(
  handlers: Map<string, RpcHandler>,
  browser: BrowserManager
): void {
  handlers.set("navigate", async (params: unknown) => {
    const p = asObject(params);
    if (!p || typeof p["url"] !== "string") {
      throw new Error("navigate requires 'url' parameter");
    }
    return browser.navigate(p["url"]);
  });

  handlers.set("click", async (params: unknown) => {
    const p = asObject(params);
    if (!p || typeof p["selector"] !== "string") {
      throw new Error("click requires 'selector' parameter");
    }
    await browser.click(p["selector"]);
    return { success: true };
  });

  handlers.set("type", async (params: unknown) => {
    const p = asObject(params);
    if (!p || typeof p["selector"] !== "string") {
      throw new Error("type requires 'selector' parameter");
    }
    if (typeof p["text"] !== "string") {
      throw new Error("type requires 'text' parameter");
    }
    await browser.type(p["selector"], p["text"]);
    return { success: true };
  });

  handlers.set("eval", async (params: unknown) => {
    const p = asObject(params);
    if (!p || typeof p["script"] !== "string") {
      throw new Error("eval requires 'script' parameter");
    }
    return browser.evaluate(p["script"]);
  });

  handlers.set("wait", async (params: unknown) => {
    const p = asObject(params);
    if (!p || typeof p["selector"] !== "string") {
      throw new Error("wait requires 'selector' parameter");
    }
    const timeout = p["timeout"] ? Number(p["timeout"]) : undefined;
    await browser.waitForSelector(p["selector"], timeout);
    return { success: true };
  });

  handlers.set("screenshot", async (params: unknown) => {
    const p = asObject(params);
    const path = p && typeof p["path"] === "string" ? p["path"] : undefined;
    return browser.screenshot(path);
  });

  handlers.set("status", () => {
    return Promise.resolve({
      currentUrl: browser.getCurrentUrl(),
    });
  });

  handlers.set("snapshot", () => {
    return generateSnapshot(browser.getPage());
  });

  handlers.set("shutdown", () => {
    // Trigger graceful shutdown
    // The actual shutdown logic is handled in server.ts
    // This handler just acknowledges the request
    setTimeout(() => {
      process.exit(0);
    }, 100);
    return Promise.resolve({ success: true });
  });
}
