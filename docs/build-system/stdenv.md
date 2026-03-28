# Custom stdenv

`modules/common/stdenv/default.nix` overrides the global stdenv for both the stable and unstable nixpkgs channels. Every package built with `mkDerivation` gets several modifications:

1. **mold linker** — replaces GNU ld for faster, parallel linking
2. **ccache wrapping** — C/C++ compilers are wrapped with ccache for compilation caching
3. **Additional hardening flags** — extra compiler hardening beyond the nixpkgs defaults

Since overriding the stdenv triggers a full build of all derivations, the overlay also disables reference checks (`allowedRequisites = null`) as the strict isolation of bootstrap packages is broken. 

## mold Linker

[mold](https://github.com/rui314/mold) is injected as a `nativeBuildInput` and activated via compiler flags:

- **C/C++**: `-fuse-ld=mold` added to `NIX_CFLAGS_LINK` (via `env.NIX_CFLAGS_LINK`)
- **Rust**: `-C link-arg=-fuse-ld=mold` added to `RUSTFLAGS` (via `env.RUSTFLAGS`)

mold is built from a clean nixpkgs import (no overlays) to avoid a circular dependency — the stdenv overlay adds mold, and mold needs stdenv to build.

### mold Exclusions

Some packages are incompatible with mold and opt out via the `moldExcludedNames` list:

Packages opt out by adding their `pname` to `moldExcludedNames`.

## ccache Wrapping

The stdenv wraps every C/C++ compiler with ccache via a `preConfigure` hook. Each derivation
gets environment variables pointing to the local cache and R2-backed remote storage. Packages
can opt out by adding their `pname` to `ccacheExcludedNames`.

For Rust builds, a cargo wrapper intercepts `CC_<target>` and `HOST_CC`/`HOST_CXX` variables
set by nixpkgs cargo build hooks, ensuring C/C++ compilation within Rust crates also uses ccache.

See [Compiler cache](ccache.md) for the full ccache architecture, environment variables,
exclusion list, and R2 backend details.

## Hardening Flags

The overlay adds hardening flags beyond the nixpkgs defaults. Currently enabled:

| Flag | Compiler option | Effect |
|---|---|---|
| `trivialautovarinit` | `-ftrivial-auto-var-init=pattern` | Zero-init automatic variables to prevent info leaks |

Available but commented out:

| Flag | Compiler option | Effect |
|---|---|---|
| `glibcxxassertions` | `-D_GLIBCXX_ASSERTIONS` | Enable libstdc++ runtime assertions |
| `nostrictaliasing` | `-fno-strict-aliasing` | Disable strict aliasing (safer for C code with type-punning) |
| `strictflexarrays3` | `-fstrict-flex-arrays=3` | Strict flexible array member bounds checking |
| `libcxxhardeningextensive` | `-D_LIBCPP_HARDENING_MODE=...` | Extensive libc++ hardening mode |
| `shadowstack` | `-fcf-protection=return` | Intel CET shadow stack for return address protection |

### Hardening Exclusions

Compilers, assemblers, and test frameworks are excluded from the extra hardening flags (they still get standard nixpkgs hardening):

`gcc`, `gfortran`, `clang`, `llvm`, `ldc`, `dmd`, `fpc`, `binutils`, `nasm`, `yasm`, `dejagnu`

## Other Modifications

- **`doCheck = false`** — Tests are disabled globally. Per-package test overrides caused by the custom stdenv live in `modules/patches/`.

## CAS Exclusions

Content-addressed derivations are enabled globally via `contentAddressedByDefault`. Packages that
break with content-addressing can opt out via the `casExcludedNames` list or by setting `__noCas = true`
via `overrideAttrs`, following the same pattern as mold and ccache exclusions.

When a package is excluded, the stdenv sets `__contentAddressed = false` on the derivation, reverting
it to input-addressed output hashing.

