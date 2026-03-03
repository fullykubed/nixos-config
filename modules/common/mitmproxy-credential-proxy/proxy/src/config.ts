import { readFileSync } from "node:fs";
import * as log from "./logger";

export interface CredentialMapping {
  domain: string;
  header: string;
  value_prefix: string;
  secret_path: string;
}

export interface Config {
  domainMap: Map<string, CredentialMapping>;
}

export function loadConfig(): Config {
  const configPath = process.env.CREDENTIAL_PROXY_CONFIG;
  if (!configPath) {
    log.warn("CREDENTIAL_PROXY_CONFIG not set, proxy will not inject credentials");
    return { domainMap: new Map() };
  }

  try {
    const raw = readFileSync(configPath, "utf-8");
    const mappings: CredentialMapping[] = JSON.parse(raw);
    const domainMap = new Map<string, CredentialMapping>();
    for (const m of mappings) {
      domainMap.set(m.domain, m);
      log.info(`Configured credential injection for ${m.domain}`);
    }
    return { domainMap };
  } catch (e) {
    log.error(`Failed to load config from ${configPath}:`, e);
    return { domainMap: new Map() };
  }
}
