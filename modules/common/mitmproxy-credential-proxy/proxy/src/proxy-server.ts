import * as net from "node:net";
import * as tls from "node:tls";

import type { Config, CredentialMapping } from "./config";
import { injectCredentials } from "./credential-injector";
import * as log from "./logger";
import { getDomainCert } from "./tls-manager";

function parseHostPort(target: string): { host: string; port: number } {
  const colon = target.lastIndexOf(":");
  if (colon === -1) return { host: target, port: 443 };
  return {
    host: target.slice(0, colon),
    port: parseInt(target.slice(colon + 1), 10),
  };
}

function forwardRequest(
  raw: string,
  host: string,
  port: number,
  mapping: CredentialMapping,
  clearSocket: tls.TLSSocket,
): void {
  const modified = injectCredentials(raw, mapping);
  const requestLine = modified.split("\r\n")[0];

  const upstream = tls.connect({ host, port, servername: host }, () => {
    upstream.write(modified);
  });

  let firstChunk = true;
  upstream.on("data", (chunk: Buffer) => {
    if (firstChunk) {
      firstChunk = false;
      const head = chunk.toString("utf-8", 0, Math.min(chunk.length, 128));
      const match = head.match(/^HTTP\/\d\.\d (\d{3})/);
      if (match) {
        const status = parseInt(match[1], 10);
        if (status === 401 || status === 403) {
          log.warn(`Auth failed: ${requestLine} -> ${status}`);
        } else {
          log.debug(`${requestLine} -> ${status}`);
        }
      }
    }
    clearSocket.write(chunk);
  });

  upstream.on("end", () => clearSocket.end());
  upstream.on("error", (err) => {
    log.error(`Upstream error for ${requestLine} (${host}:${port}):`, err.message);
    clearSocket.write("HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n");
    clearSocket.end();
  });

  clearSocket.on("error", (err) => {
    log.debug(`Client socket error during forward to ${host}:`, err.message);
    upstream.destroy();
  });
}

export function createProxyServer(
  config: Config,
  listenHost: string,
  listenPort: number,
): void {
  // Per-domain TLS servers for MITM. Each gets its own cert.
  // Uses node:tls (not Bun.listen+upgradeTLS) to avoid a Bun segfault.
  const domainPorts = new Map<string, number>();

  for (const [domain, mapping] of config.domainMap) {
    const { cert, key } = getDomainCert(domain);
    const tlsSrv = tls.createServer({ cert, key }, (clearSocket) => {
      clearSocket.on("data", (data: Buffer) => {
        const raw = data.toString();
        forwardRequest(raw, domain, 443, mapping, clearSocket);
      });
      clearSocket.on("error", (err) => {
        log.debug(`TLS error for ${domain}:`, err.message);
      });
    });

    tlsSrv.listen(0, "127.0.0.1", () => {
      const addr = tlsSrv.address() as net.AddressInfo;
      domainPorts.set(domain, addr.port);
      log.info(`TLS server for ${domain} on 127.0.0.1:${addr.port}`);
    });

    tlsSrv.on("error", (err) => {
      log.error(`TLS server error for ${domain}:`, err.message);
    });
  }

  // Front-facing proxy — pure node:net.
  const frontServer = net.createServer((clientSocket) => {
    clientSocket.once("data", (connectData) => {
      const text = connectData.toString();
      const firstLine = text.split("\r\n")[0];

      if (!firstLine.startsWith("CONNECT ")) {
        clientSocket.write("HTTP/1.1 405 Method Not Allowed\r\nContent-Length: 0\r\n\r\n");
        clientSocket.end();
        return;
      }

      const target = firstLine.split(" ")[1];
      const { host, port } = parseHostPort(target);

      const mitmPort = domainPorts.get(host);
      if (mitmPort !== undefined) {
        // MITM: relay client through the per-domain TLS server
        log.debug(`MITM intercepting ${host}:${port}`);
        clientSocket.write("HTTP/1.1 200 Connection Established\r\n\r\n");

        const relay = net.connect(mitmPort, "127.0.0.1", () => {
          // Bidirectional forwarding between client and TLS server
          clientSocket.on("data", (chunk) => relay.write(chunk));
          relay.on("data", (chunk) => clientSocket.write(chunk));
          relay.on("end", () => clientSocket.end());
          clientSocket.on("end", () => relay.end());
        });

        relay.on("error", (err) => {
          log.debug(`MITM relay error for ${host}:`, err.message);
          clientSocket.end();
        });
      } else {
        // Tunnel: direct TCP forwarding, no MITM
        log.debug(`Tunneling ${host}:${port}`);
        const remote = net.connect(port, host, () => {
          clientSocket.write("HTTP/1.1 200 Connection Established\r\n\r\n");
          clientSocket.on("data", (chunk) => remote.write(chunk));
          remote.on("data", (chunk) => clientSocket.write(chunk));
          remote.on("end", () => clientSocket.end());
          clientSocket.on("end", () => remote.end());
        });
        remote.on("error", (err) => {
          log.warn(`Tunnel error to ${host}:${port}:`, err.message);
          clientSocket.end();
        });
      }
    });

    clientSocket.on("error", (err) => {
      log.debug("Client socket error:", err.message);
    });
  });

  frontServer.listen(listenPort, listenHost, () => {
    log.info(`Proxy listening on ${listenHost}:${listenPort}`);
  });

  frontServer.on("error", (err) => {
    log.error("Server error:", err.message);
    process.exit(1);
  });
}
