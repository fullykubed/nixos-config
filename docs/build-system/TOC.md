# Table of Contents — docs/build-system/

- **README.md** — Build system overview: all four layers (stdenv, compiler cache, remote builders, binary cache), architecture diagram, component index, and build flow.
- **stdenv.md** — Custom stdenv: mold linker, ccache compiler wrapping, hardening flags, package exclusions, and sandbox integration.
- **ccache.md** — R2-backed compiler cache: three-tier storage hierarchy, s3fs mount, s5cmd sync service, and filesystem layout.
- **remote-builders/** — Hetzner Cloud infrastructure: ephemeral builder VMs, binary cache server, setup, and troubleshooting.
