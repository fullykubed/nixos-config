const PREFIX = "[credential-proxy]";

export function info(...args: unknown[]): void {
  console.error(PREFIX, ...args);
}

export function warn(...args: unknown[]): void {
  console.error(PREFIX, "WARN", ...args);
}

export function error(...args: unknown[]): void {
  console.error(PREFIX, "ERROR", ...args);
}

export function debug(...args: unknown[]): void {
  if (process.env.CREDENTIAL_PROXY_DEBUG) {
    console.error(PREFIX, "DEBUG", ...args);
  }
}
