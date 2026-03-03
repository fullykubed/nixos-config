import forge from "node-forge";
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import * as log from "./logger";

interface CachedCert {
  cert: string;
  key: string;
}

let caCert: forge.pki.Certificate;
let caKey: forge.pki.PrivateKey;
const certCache = new Map<string, CachedCert>();

export function initCA(stateDir: string): void {
  const certPath = `${stateDir}/mitmproxy-ca-cert.pem`;
  const keyPath = `${stateDir}/ca-key.pem`;

  if (!existsSync(stateDir)) {
    mkdirSync(stateDir, { recursive: true });
  }

  if (existsSync(certPath) && existsSync(keyPath)) {
    log.info("Loading existing CA certificate");
    caCert = forge.pki.certificateFromPem(readFileSync(certPath, "utf-8"));
    caKey = forge.pki.privateKeyFromPem(readFileSync(keyPath, "utf-8"));
    return;
  }

  log.info("Generating new CA certificate");
  const keys = forge.pki.rsa.generateKeyPair(2048);
  caCert = forge.pki.createCertificate();
  caCert.publicKey = keys.publicKey;
  caCert.serialNumber = "01";
  caCert.validity.notBefore = new Date();
  caCert.validity.notAfter = new Date();
  caCert.validity.notAfter.setFullYear(caCert.validity.notBefore.getFullYear() + 10);

  const attrs = [
    { name: "commonName", value: "Credential Proxy CA" },
    { name: "organizationName", value: "credential-proxy" },
  ];
  caCert.setSubject(attrs);
  caCert.setIssuer(attrs);
  caCert.setExtensions([
    { name: "basicConstraints", cA: true },
    {
      name: "keyUsage",
      keyCertSign: true,
      cRLSign: true,
    },
  ]);
  caCert.sign(keys.privateKey, forge.md.sha256.create());
  caKey = keys.privateKey;

  writeFileSync(certPath, forge.pki.certificateToPem(caCert), { mode: 0o644 });
  writeFileSync(keyPath, forge.pki.privateKeyToPem(caKey), { mode: 0o600 });
  log.info(`CA certificate written to ${certPath}`);
}

export function getDomainCert(domain: string): CachedCert {
  const cached = certCache.get(domain);
  if (cached) return cached;

  const keys = forge.pki.rsa.generateKeyPair(2048);
  const cert = forge.pki.createCertificate();
  cert.publicKey = keys.publicKey;
  cert.serialNumber = Date.now().toString(16);
  cert.validity.notBefore = new Date();
  cert.validity.notAfter = new Date();
  cert.validity.notAfter.setFullYear(cert.validity.notBefore.getFullYear() + 1);

  cert.setSubject([{ name: "commonName", value: domain }]);
  cert.setIssuer(caCert.subject.attributes);
  cert.setExtensions([
    {
      name: "subjectAltName",
      altNames: [{ type: 2, value: domain }],
    },
  ]);
  cert.sign(caKey, forge.md.sha256.create());

  const result: CachedCert = {
    cert: forge.pki.certificateToPem(cert),
    key: forge.pki.privateKeyToPem(keys.privateKey),
  };
  certCache.set(domain, result);
  log.debug(`Generated certificate for ${domain}`);
  return result;
}
