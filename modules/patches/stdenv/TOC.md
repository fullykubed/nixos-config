# Table of Contents — modules/patches/stdenv/

- **default.nix** - NixOS module that overrides stdenv to use the mold linker globally (faster than GNU ld) and enable additional hardening flags (trivialautovarinit). Disables reference checks for bootstrap package patching. Per-package test/build overrides caused by the custom stdenv live in modules/patches/.
