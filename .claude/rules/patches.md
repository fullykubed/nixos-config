---
paths:
  - "modules/patches/**/*.nix"
  - "modules/patches/**/*.patch"
---

Follow the existing patch module pattern. Use the CVE skill (`/CVE`) for CVE-related work.

Reference a nearby `default.nix` in `modules/patches/` for the overlay pattern before writing new patch modules.
