# headroom/

Nix package and systemd service definition for the headroom context-compression proxy.

- `default.nix` — Builds headroom-ai from its PyPI tarball via `buildPythonPackage` and declares the `headroom-proxy` systemd user service that listens on `127.0.0.1:8787`.
- `patches/` — Unified-diff patches applied to the headroom source during the Nix build; currently contains the `ANTHROPIC_TARGET_API_URL` env-var wiring patch intended for upstream submission.
