import { readFileSync } from "node:fs";
import type { CredentialMapping } from "./config";
import * as log from "./logger";

export function injectCredentials(
  rawRequest: string,
  mapping: CredentialMapping,
): string {
  try {
    const secret = readFileSync(mapping.secret_path, "utf-8").trim();
    const value = `${mapping.value_prefix}${secret}`;

    // Insert the header after the first line (request line)
    const lineEnd = rawRequest.indexOf("\r\n");
    if (lineEnd === -1) return rawRequest;

    const injected =
      rawRequest.slice(0, lineEnd + 2) +
      `${mapping.header}: ${value}\r\n` +
      rawRequest.slice(lineEnd + 2);

    // Extract method and path for logging
    const requestLine = rawRequest.slice(0, lineEnd);
    log.info(`${requestLine} -> injected ${mapping.header}`);
    return injected;
  } catch (e) {
    log.warn(`Failed to read secret for ${mapping.domain}:`, e);
    return rawRequest;
  }
}
