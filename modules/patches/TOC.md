# Table of Contents — modules/patches/

- **default.nix** - NixOS module that imports all per-package patch submodules.

## Per-Package Patch Folders

Each folder contains a `default.nix` with the overlay entry and any associated `.patch` files.

- **assimp/** - CVE-2025-11277 heap buffer overflow fix plus uninitialized variable fix.
- **avahi/** - Four CVE patches for CNAME crash, timing crash, D-Bus crash, and recursive CNAME stack exhaustion.
- **binutils/** - Three CVE patches for memory corruption, memory leak, and DWARF handler issues.
- **busybox/** - CVE patches for HTTP header injection and terminal escape filename hiding.
- **coreutils/** - Skip tests that fail with custom stdenv hardening flags or in sandbox.
- **cups-filters/** - CVE-2025-64524 heap-buffer-overflow fix in rastertopclx.
- **deno/** - Skip os.cpus() test that fails in sandbox due to CPU count mismatch.
- **dotnet/** - FileVersion overflow fix for 2026 date calculations in azure-activedirectory-identitymodel-extensions.
- **exiv2/** - Pulls exiv2 0.28.8 from unstable to fix three CVEs (OOB reads, exception in PSD parser).
- **ffmpeg/** - FFmpeg 7.1.3 from unstable with CVE-2025-22921 backport for three variants.
- **firefox/** - Disables LTO to prevent OOM during libxul.so linking.
- **fluidsynth/** - CVE-2025-68617 use-after-free fix in DLS file handling.
- **gd/** - Forces rebuild with fixed libavif 1.3.0 for CVE-2025-48174/48175.
- **gegl/** - Rebuilds with OpenEXR 3.4.5 instead of legacy openexr_2 to fix 11 CVEs.
- **gimp/** - GIMP 3.0.8 version bump fixing 9 CVEs with dependency chain overrides.
- **git/** - Disable install checks that fail in Nix sandbox due to protocol restrictions.
- **gjs/** - Skip GTK tests not found in sandbox with custom stdenv.
- **gnupg/** - Two CVE patches for armor parser corruption and formfeed signature bypass.
- **go/** - Go 1.25.7 from unstable fixing TLS session resumption bypass and cgo injection.
- **gstreamer/** - GStreamer 1.26.11 version bump fixing 10 RCE CVEs (ZDI-disclosed, CVSS 7.8-8.8).
- **gpsd/** - Two CVE patches for NMEA2000 buffer overflow and NAVCOM integer underflow.
- **gvfs/** - Forces rebuild with libcdio 2.3.0 for CVE-2024-36600.
- **imagemagick/** - ImageMagick 7.1.2-15 from unstable fixing 31 CVEs.
- **jbig2dec/** - CVE-2023-46361 SEGV fix via uninitialized allocator in CLI tool.
- **jq/** - Pulls jq 1.8.1 from unstable to fix three CVEs (integer overflow, buffer overflows).
- **libaom/** - Yasm-to-NASM migration with cmake optimization check fix.
- **libadwaita/** - Skip test-dialog that fails in sandbox with custom stdenv hardening.
- **libass/** - Yasm-to-NASM migration for subtitle renderer.
- **libavif/** - Forces nasm-based libaom to eliminate yasm CVEs.
- **libcdio/** - Security update to 2.3.0 fixing CVE-2024-36600 buffer overflow.
- **libgcrypt/** - Skip t-kdf Argon2 test that aborts with custom stdenv.
- **libgphoto2/** - Forces rebuild with patched gd for libavif CVE chain.
- **libheif/** - Forces nasm-based libaom to eliminate yasm CVEs.
- **libjxl/** - Forces rebuild with patched openexr to eliminate openexr-3.3.5 CVEs.
- **libsndfile/** - Three CVE patches for IRCAM buffer overflow, OGG OOB read, and MP3 memory leak.
- **libssh/** - CVE-2026-3731 out-of-bounds read fix in SFTP extension name handler.
- **libvpx/** - Yasm-to-NASM migration with configure flag update.
- **lttng-ust/** - Disable trivialautovarinit due to VLA incompatibility with tracepoint macros.
- **lua/** - CVE-2021-43519 stack overflow fix for Lua 5.2.
- **mupdf/** - CVE-2026-25556 double-free fix in barcode decoding.
- **onnxruntime/** - Disable unit tests to avoid CMake 4 GTest detection regression.
- **openexr/** - OpenEXR 3.4.5 version bump fixing 10 CVEs plus openjph dependency.
- **p11-kit/** - Disable tests that fail in sandbox lacking PKCS#11 token infrastructure.
- **perl/** - Perl 5.42.0 from unstable fixing CVE-2024-56406 heap buffer overflow.
- **python/** - Test skip overrides for websockets, rich, and mss sandbox issues.
- **stdenv/** - Custom stdenv with additional hardening flags, reference check bypass for CVE patches on bootstrap packages, and mold linker globally.
- **sway/** - Fix maybe-uninitialized false positive from trivialautovarinit + -Werror.
- **taglib/** - CVE-2023-47466 NULL pointer dereference fix in taglib_1.
- **texinfo/** - Disable tests that fail in sandbox due to locale/encoding issues.
- **waybar/** - Disable tests where catch2 not found via pkg-config with custom stdenv.
- **xvidcore/** - Yasm-to-NASM migration for MPEG-4 codec.
- **zlib/** - CVE-2026-27171 infinite loop fix in crc32_combine.
