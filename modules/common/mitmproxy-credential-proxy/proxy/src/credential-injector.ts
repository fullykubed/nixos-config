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

    const lineEnd = rawRequest.indexOf("\r\n");
    if (lineEnd === -1) return rawRequest;

    const requestLine = rawRequest.slice(0, lineEnd);
    const rest = rawRequest.slice(lineEnd + 2);

    // Remove any existing header with the same name so it doesn't
    // overwrite the injected one when Headers.set() processes them
    const headerPattern = new RegExp(
      `^${mapping.header}:.*\\r\\n`,
      "gim",
    );
    const cleaned = rest.replace(headerPattern, "");

    const injected =
      requestLine +
      "\r\n" +
      `${mapping.header}: ${value}\r\n` +
      cleaned;

    log.info(`${requestLine} -> injected ${mapping.header}`);
    return injected;
  } catch (e) {
    log.error(
      `Failed to read secret for ${mapping.domain} from ${mapping.secret_path} — ` +
      `requests to this domain will not be authenticated: ${e instanceof Error ? e.message : e}`,
    );
    return rawRequest;
  }
}
