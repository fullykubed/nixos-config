/**
 * CLI command implementations for dev-browser
 */

import type { DevBrowserClient } from "./client";

/**
 * Get AI-optimized snapshot of the current page
 */
export async function snapshot(client: DevBrowserClient): Promise<void> {
  const result = await client.send({ method: "snapshot", params: {} });
  console.log(JSON.stringify(result, null, 2));
}

/**
 * Navigate to a URL
 */
export async function navigate(
  client: DevBrowserClient,
  url: string
): Promise<void> {
  const result = await client.send({ method: "navigate", params: { url } });
  console.log(JSON.stringify(result, null, 2));
}

/**
 * Click an element by selector
 */
export async function click(
  client: DevBrowserClient,
  selector: string
): Promise<void> {
  const result = await client.send({ method: "click", params: { selector } });
  console.log(JSON.stringify(result, null, 2));
}

/**
 * Type text into an element
 */
export async function type(
  client: DevBrowserClient,
  selector: string,
  text: string
): Promise<void> {
  const result = await client.send({
    method: "type",
    params: { selector, text },
  });
  console.log(JSON.stringify(result, null, 2));
}

/**
 * Evaluate JavaScript in the page
 */
export async function evaluate(
  client: DevBrowserClient,
  script: string
): Promise<void> {
  const result = await client.send({ method: "eval", params: { script } });
  console.log(JSON.stringify(result, null, 2));
}

/**
 * Wait for a selector to appear
 */
export async function wait(
  client: DevBrowserClient,
  selector: string,
  timeout?: number
): Promise<void> {
  const result = await client.send({
    method: "wait",
    params: { selector, timeout: timeout || 30000 },
  });
  console.log(JSON.stringify(result, null, 2));
}

/**
 * Take a screenshot of the current page
 */
export async function screenshot(
  client: DevBrowserClient,
  path?: string
): Promise<void> {
  const result = await client.send({
    method: "screenshot",
    params: { path },
  });

  if (path) {
    console.log(JSON.stringify({ saved: path }, null, 2));
  } else {
    // Output base64 for Claude to process
    console.log(JSON.stringify(result, null, 2));
  }
}

/**
 * Get server status
 */
export async function status(client: DevBrowserClient): Promise<void> {
  const result = await client.send({ method: "status", params: {} });
  console.log(JSON.stringify(result, null, 2));
}
