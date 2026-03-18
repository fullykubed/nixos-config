import { loadConfig } from "./config";
import * as log from "./logger";
import { createProxyServer } from "./proxy-server";
import { initCA } from "./tls-manager";

const LISTEN_HOST = "127.0.0.1";
const LISTEN_PORT = 8080;

const stateDir =
  process.env.CREDENTIAL_PROXY_STATE_DIR || "/var/lib/mitmproxy-credential-proxy";

log.info("Starting credential proxy");

const config = loadConfig();
initCA(stateDir);
createProxyServer(config, LISTEN_HOST, LISTEN_PORT);
