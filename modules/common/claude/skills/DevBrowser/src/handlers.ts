/**
 * RPC method handlers for browser operations
 */

import type { BrowserManager } from "./browser";
import type { RpcHandler } from "./types";
import { generateSnapshot } from "./snapshot";

/**
 * Register all RPC handlers for browser operations
 */
export function registerHandlers(
  handlers: Map<string, RpcHandler>,
  browser: BrowserManager
): void {
  handlers.set("navigate", async (params: any) => {
    if (!params?.url || typeof params.url !== "string") {
      throw new Error("navigate requires 'url' parameter");
    }
    return browser.navigate(params.url);
  });

  handlers.set("click", async (params: any) => {
    if (!params?.selector || typeof params.selector !== "string") {
      throw new Error("click requires 'selector' parameter");
    }
    await browser.click(params.selector);
    return { success: true };
  });

  handlers.set("type", async (params: any) => {
    if (!params?.selector || typeof params.selector !== "string") {
      throw new Error("type requires 'selector' parameter");
    }
    if (!params?.text || typeof params.text !== "string") {
      throw new Error("type requires 'text' parameter");
    }
    await browser.type(params.selector, params.text);
    return { success: true };
  });

  handlers.set("eval", async (params: any) => {
    if (!params?.script || typeof params.script !== "string") {
      throw new Error("eval requires 'script' parameter");
    }
    return browser.evaluate(params.script);
  });

  handlers.set("wait", async (params: any) => {
    if (!params?.selector || typeof params.selector !== "string") {
      throw new Error("wait requires 'selector' parameter");
    }
    const timeout = params.timeout ? Number(params.timeout) : undefined;
    await browser.waitForSelector(params.selector, timeout);
    return { success: true };
  });

  handlers.set("screenshot", async (params: any) => {
    const path = params?.path && typeof params.path === "string" ? params.path : undefined;
    return browser.screenshot(path);
  });

  handlers.set("status", async () => {
    return {
      currentUrl: browser.getCurrentUrl(),
    };
  });

  handlers.set("snapshot", async () => {
    return generateSnapshot(browser.getPage());
  });

  handlers.set("shutdown", async () => {
    // Trigger graceful shutdown
    // The actual shutdown logic is handled in server.ts
    // This handler just acknowledges the request
    setTimeout(() => {
      process.exit(0);
    }, 100);
    return { success: true };
  });
}
