# Table of Contents — patches/

- **default.nix** - Overlay that applies all CVE security patches to affected packages, with configurable hardening flags and toolchain options.
- **cves/** - Individual patch files for CVE vulnerabilities not yet fixed in upstream nixpkgs, covering packages like libsndfile, lua, libcdio, and others.
- **fixes/** - Directory reserved for non-CVE bug fix patches (currently empty).
