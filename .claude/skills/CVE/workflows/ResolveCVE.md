# ResolveCVE Workflow

This workflow guides you through resolving a specific CVE vulnerability by either applying a patch or creating a whitelist entry.

## Prerequisites

Before proceeding, verify:
1. **CVE ID is known** - The user should provide a specific CVE (e.g., CVE-2025-12345)
2. **CVE is triaged** - Confirm this is a real vulnerability, not a false positive
3. **Package is identified** - Know which package needs patching

If any prerequisite is missing, switch to the IdentifyCVE workflow first.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Research the CVE

Gather complete information about the vulnerability and available fixes.

**Fetch CVE details:**
```bash
# Get full CVE information from NVD
WebFetch https://nvd.nist.gov/vuln/detail/CVE-XXXX-XXXXX
```

**Extract key information:**
| Field | What to Find |
|-------|--------------|
| Description | What the vulnerability does |
| CVSS Score | Severity rating |
| Attack Vector | Network, Local, Adjacent, Physical |
| Fixed Version | Version where it's fixed upstream |
| References | Links to patches, advisories, commits |

### 2. Check nixpkgs Status

Determine if nixpkgs already has the fix.

**Check current nixpkgs version:**
```bash
nix eval nixpkgs#<package>.version
```

**Check nixpkgs-unstable:**
```bash
nix eval nixpkgs-unstable#<package>.version
```

**Search for existing patches in nixpkgs:**
```bash
# Check package definition
WebFetch https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/by-name/<first-two-letters>/<package>/package.nix
```

**Search for PRs/issues using Exa:**
```
mcp__exa__web_search_exa with query: "site:github.com/NixOS/nixpkgs CVE-XXXX-XXXXX"
```

**Decision point:**
- If nixpkgs-unstable has the fix → Update flake input or overlay unstable version
- If PR exists and merged → Wait for channel update or cherry-pick
- If no fix in nixpkgs → Continue to Step 3

### 3. Find the Upstream Fix

Locate the patch that fixes the vulnerability.

**Common sources:**
1. **CVE references** - Often link directly to fix commits
2. **Security advisories** - GitHub Security Advisories, project security pages
3. **Git history** - Search commits mentioning the CVE

**Search strategies using Exa:**
```
# Search for fix commits and patches
mcp__exa__web_search_exa with query: "CVE-XXXX-XXXXX fix commit patch <package-name>"

# Search for security advisories
mcp__exa__web_search_exa with query: "CVE-XXXX-XXXXX security advisory <package-name>"

# Get code context for patch details
mcp__exa__get_code_context_exa with query: "CVE-XXXX-XXXXX <package-name> patch"
```

**Direct GitHub checks:**
```bash
# Check security advisories page
WebFetch https://github.com/<owner>/<repo>/security/advisories
```

**Verify the fix:**
- Read the patch to understand what it changes
- Confirm it addresses the specific vulnerability
- Check if it applies cleanly to the nixpkgs version

### 4. Choose Resolution Method

Based on research, select the appropriate resolution:

| Situation | Method |
|-----------|--------|
| Patch available and applies cleanly | **Option A: Create Patch Overlay** |
| Risk accepted, no immediate patch needed | **Option B: Create Whitelist Entry** |
| Fix requires version bump with breaking changes | Evaluate trade-offs with user |

### 5A. Create Patch Overlay

If applying a patch:

#### Patch Naming Convention (CRITICAL)

**Patch files MUST be named `CVE-XXXX-XXXXX.patch` (CVE ID only, no description suffix).**

| Correct | Incorrect |
|---------|-----------|
| `CVE-2025-68973.patch` | `CVE-2025-68973-gnupg-armor-parser.patch` |
| `CVE-2025-68468.patch` | `CVE-2025-68468-avahi-cname-ttl-crash.patch` |

**Why this matters:** Vulnix has CVE patch auto-detection that scans patch filenames using the regex `CVE-\d{4}-\d+`. When a patch filename matches a CVE ID, vulnix automatically excludes that CVE from vulnerability reports for the patched package. If you add description suffixes, the auto-detection still works, but following the simple convention ensures consistency with nixpkgs upstream patterns.

See: https://github.com/nix-community/vulnix#cve-patch-auto-detection

**For multiple patches fixing the same CVE**, append a number:
- `CVE-2025-68617.patch` (first patch)
- `CVE-2025-68617-2.patch` (second patch)

**Create the package patch directory (if new package):**
```bash
mkdir -p modules/patches/<package>
```

**Download the patch:**
```bash
curl -sL "https://github.com/<owner>/<repo>/commit/<sha>.patch" \
  -o modules/patches/<package>/CVE-XXXX-XXXXX.patch
```

**Verify the patch:**
```bash
# Check patch applies (in a nix-shell with the package source)
nix-shell -p <package> --run "patch --dry-run -p1 < modules/patches/<package>/CVE-XXXX-XXXXX.patch"
```

**Create or update the package module** (`modules/patches/<package>/default.nix`):

Each patch module is a NixOS module that applies its overlay to the appropriate nixpkgs set(s). Both `nixpkgs` and `nixpkgs-unstable` use the custom hardened stdenv, but a patch should only target the set(s) that actually provide the package on the live system.

#### Determining which nixpkgs set to target (REQUIRED)

Before writing the module, check where the package comes from:

```bash
# Check if the package is pulled from nixpkgs-unstable in the config
grep -r 'nixpkgs-unstable\.' modules/ --include='*.nix' | grep '<package>'

# Check if it exists in the standard nixpkgs overlay/config
grep -r 'pkgs\.<package>\|prev\.<package>' modules/ --include='*.nix'
```

| Finding | Target |
|---------|--------|
| Package only used from `nixpkgs` (the default) | `nixpkgs.overlays` only |
| Package explicitly pulled from `nixpkgs-unstable` | `nixpkgs-unstable.overlays` only |
| Package used from both sets | Both `nixpkgs.overlays` and `nixpkgs-unstable.overlays` |
| Foundational package (stdenv, coreutils, gcc, etc.) | Both — these are built by both sets |

**Template — nixpkgs only (most common):**
```nix
# <package>: CVE-XXXX-XXXXX (CVSS X.X Severity): <brief description>
# See: https://nvd.nist.gov/vuln/detail/CVE-XXXX-XXXXX
_: {
  nixpkgs.overlays = [
    (_final: prev: {
      <package> = prev.<package>.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-XXXX-XXXXX.patch
        ];
      });
    })
  ];
}
```

**Template — nixpkgs-unstable only:**
```nix
# <package>: CVE-XXXX-XXXXX (CVSS X.X Severity): <brief description>
# See: https://nvd.nist.gov/vuln/detail/CVE-XXXX-XXXXX
_: {
  nixpkgs-unstable.overlays = [
    (_final: prev: {
      <package> = prev.<package>.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-XXXX-XXXXX.patch
        ];
      });
    })
  ];
}
```

**Template — both sets (foundational packages or when used from both):**
```nix
# <package>: CVE-XXXX-XXXXX (CVSS X.X Severity): <brief description>
# See: https://nvd.nist.gov/vuln/detail/CVE-XXXX-XXXXX
_:
let
  overlay = _final: prev: {
    <package> = prev.<package>.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./CVE-XXXX-XXXXX.patch
      ];
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
```

**Add the import to `modules/patches/default.nix`** (keep alphabetical order):
```nix
imports = [
  # ...existing imports...
  ./<package>
  # ...
];
```

### 5B. Create Whitelist Entry (Ignore CVE)

Use whitelisting when:
- **False positive**: CVE doesn't actually apply (different software, wrong platform, etc.)
- **Accepted risk**: Vulnerability exists but risk is mitigated or acceptable
- **No fix available**: Upstream hasn't released a patch yet
- **Feature not used**: Vulnerable code path is never executed in your configuration

#### User Confirmation Required (MANDATORY)

**For "accepted risk" entries (NOT false positives)**, you MUST get explicit user approval:

1. Present the CVE to the user:
   - CVE ID and CVSS score
   - What the vulnerability allows (RCE, DoS, info disclosure, etc.)
   - Attack vector (Network, Local, etc.)
   - Which package/version is affected

2. Explain your risk assessment:
   - Why a patch isn't available or practical
   - Any mitigating factors (local-only, sandboxed, etc.)

3. Ask explicitly: "Do you accept this risk and want me to whitelist this CVE?"

4. Only proceed with whitelisting after receiving "yes" or equivalent confirmation

**This does NOT apply to clear false positives** (wrong software, wrong platform, already fixed version).

**File location:** `modules/common/vulnix-scanner/whitelist.toml`

The whitelist is a TOML file that is automatically applied whenever `vulnix` runs (via a wrapper script). No need to pass `-w` manually.

#### Whitelist Organization (REQUIRED)

The whitelist MUST be organized into clearly labeled sections. When adding new entries:

1. **Identify the false positive category** - What type of collision/issue is this?
2. **Find the appropriate section** - Add to existing section or create new one
3. **Document the dependency chain** - Note what top-level package pulls in the dep
4. **Include version info** - Specify the vulnerable version and what it actually is

**Whitelist sections (in order):**

| Section | Description | Example |
|---------|-------------|---------|
| **HASKELL ECOSYSTEM** | Haskell packages that share names with C/Rust/JS libs | curl, zlib, warp, network |
| **JENKINS PLUGIN COLLISIONS** | Jenkins plugins sharing names with CLI tools | git, xunit |
| **VS CODE EXTENSION COLLISIONS** | VS Code extensions sharing names with CLI tools | shellcheck |
| **DIFFERENT SOFTWARE - SAME NAME** | Completely unrelated software with same name | orc (GStreamer vs Apache), ranger |
| **PLATFORM/DISTRO SPECIFIC** | CVEs only affecting other platforms/distros | discord (macOS), avahi (Debian) |
| **ALREADY PATCHED VERSIONS** | CVEs fixed in installed version | lapack (OpenBLAS patched) |
| **EOL/LEGACY SOFTWARE** | Accepted risk for EOL deps needed for builds | python 2.7 |
| **BUNDLED DEPENDENCIES** | Older lib versions bundled in other packages | ffmpeg versions in video editors |

**Entry format:**

```toml
################################################################################
# SECTION N: SECTION NAME
################################################################################
# Brief description of what this section covers
################################################################################

# Package name (pulled in by: top-level-package or "system package")
# What the CVE actually affects vs what we have
["package-name"]          # Version-agnostic: use for FALSE POSITIVES only
["package-name-1.2.3"]    # Version-specific: use for ACCEPTED RISK & BUNDLED DEPS
cve = ["CVE-XXXX-XXXXX"]
comment = "CVE-XXXX-XXXXX (X.X Severity): Brief description of vulnerability. Why whitelisted."
```

#### Version-Specific vs Version-Agnostic Keys (IMPORTANT)

vulnix supports two whitelist key formats. Use the correct one:

| Key Format | Use When | Why |
|------------|----------|-----|
| `["package"]` | **False positives** (name collisions) | CVE affects DIFFERENT software; our package is never vulnerable regardless of version |
| `["package-1.2.3"]` | **Accepted risk** or **bundled deps** | CVE IS real; version-specific ensures we're notified when package updates (fix may be available) |

**Examples:**

```toml
# FALSE POSITIVE - Version-agnostic (CVE is for different software)
["warp"]                    # Cloudflare WARP CVE, not Haskell Warp - any version safe
cve = ["CVE-2022-2145"]

# ACCEPTED RISK - Version-specific (CVE is real, risk accepted for this version)
["libiff-0-unstable-2024-03-02"]   # Real CVE, will alert if libiff updates
cve = ["CVE-2021-32298"]
until = "2026-07-14"

# BUNDLED DEPS - Version-specific (track which bundled version has the CVE)
["ffmpeg-7.1.2"]            # Will alert if Firefox/VLC update their bundled ffmpeg
cve = ["CVE-2023-51791"]
until = "2026-07-01"
```

**Comment format (REQUIRED):**
Every whitelist entry comment MUST include:
1. **CVE ID** - The CVE identifier
2. **Severity** - CVSS score and rating (e.g., "8.8 High", "6.7 Medium")
3. **Description** - Brief description of what the vulnerability allows
4. **Reason** - Why it's whitelisted (false positive reason, or "Fixed in X.Y.Z" for patched versions)

**Example properly documented entry:**

```toml
# Haskell curl binding (pulled in by: ShellCheck, Pandoc, or Haskell tooling)
# CVEs affect libcurl C library, not the Haskell FFI binding
["curl"]
cve = [
  "CVE-2022-27776",
  "CVE-2022-32221",
]
comment = "CVE-2022-27776 (6.5 Med), CVE-2022-32221 (9.8 Crit): libcurl auth/use-after-free. Haskell curl-0.4.46 is FFI binding, not vulnerable."
```

**Finding what pulls in a dependency:**
```bash
# Check vulnix output for derivation path
vulnix --system --json | jq '.[] | select(.pname == "PACKAGE") | {name, derivation}'

# Trace dependency chain (if derivation is built)
nix why-depends /run/current-system /nix/store/HASH-package
```

#### Simple Entry Examples

**1. False Positive - Package Name Collision:**
```toml
["curl"]
cve = ["CVE-2024-12345"]
comment = "CVE-2024-12345 (7.5 High): HTTP header injection in libcurl. Haskell curl-0.4.46 is FFI binding, unaffected."
```

**2. False Positive - Different Platform:**
```toml
["discord"]
cve = ["CVE-2024-67890"]
comment = "CVE-2024-67890 (5.5 Med): Electron fuse bypass (macOS only). Linux Discord unaffected."
```

**3. False Positive - Distro-Specific:**
```toml
["avahi"]
cve = ["CVE-2024-11111"]
comment = "CVE-2024-11111 (7.8 High): Privilege escalation in Debian avahi script. NixOS uses upstream, unaffected."
```

**4. Accepted Risk - EOL Software (VERSION-SPECIFIC KEY):**
```toml
["python-2.7.18"]
cve = ["CVE-2024-22222"]
comment = "CVE-2024-22222 (9.8 Crit): RCE in Python 2.7. EOL (2020), required for legacy builds. No upstream fix. Risk accepted YYYY-MM-DD."
until = "2026-07-01"
```

**5. Multiple CVEs for Same Package:**
```toml
["network"]
cve = [
  "CVE-2021-35047",
  "CVE-2021-35048",
  "CVE-2021-35049",
]
comment = "CVE-2021-35047/48/49 (High): RCE/auth bypass in Fidelis Network product. Haskell network lib is unrelated."
```

#### Shared pname with Multiple Consumers (IMPORTANT)

When multiple top-level packages bundle different versions of the same dependency (e.g., ffmpeg), TOML doesn't allow duplicate keys. Use **inline comments** to segment CVEs by consumer within a single entry:

**Pattern for shared pname entries:**

```toml
################################################################################
# PACKAGE-NAME - Bundled versions in various packages
################################################################################
# pname: package-name (all versions share this)
#
# VERSION MAP:
#   package-name X.Y.Z  → consumer-A (reason)
#   package-name A.B.C  → consumer-B (reason)
#   package-name D.E.F  → consumer-C, consumer-D (reason)
#
# When updating a consumer, remove ONLY the CVEs for its version.
################################################################################

["package-name"]
cve = [
  #---------------------------------------------------------------------------
  # CONSUMER-A: consumer-a-version → package-name-X.Y.Z
  # Remove these when Consumer-A updates to newer package-name
  #---------------------------------------------------------------------------
  "CVE-XXXX-XXXXX",     # package-name X.Y.Z - consumer-a
  "CVE-YYYY-YYYYY",     # package-name X.Y.Z - consumer-a

  #---------------------------------------------------------------------------
  # CONSUMER-B: consumer-b-version → package-name-A.B.C
  # Remove these when Consumer-B updates to newer package-name
  #---------------------------------------------------------------------------
  "CVE-ZZZZ-ZZZZZ",     # package-name A.B.C - consumer-b

  #---------------------------------------------------------------------------
  # SHARED: CVEs affecting multiple versions
  # Check all consumers before removing
  #---------------------------------------------------------------------------
  "CVE-WWWW-WWWWW",     # package-name X.Y.Z, A.B.C - consumer-a, consumer-b
]
comment = "Bundled versions: X.Y.Z (consumer-a), A.B.C (consumer-b). See inline comments."
until = "YYYY-MM-DD"
```

**Real example (ffmpeg) - using version-specific keys:**

When multiple packages bundle different ffmpeg versions, create separate version-specific entries:

```toml
# Spotify bundles ffmpeg-4.4.6
["ffmpeg-4.4.6"]
cve = ["CVE-2022-3109", "CVE-2022-3341"]
comment = "CVEs in ffmpeg-4.4.6 bundled by Spotify. Remove when Spotify updates."
until = "2026-07-01"

# Lutris bundles ffmpeg-6.1.3
["ffmpeg-6.1.3"]
cve = ["CVE-2023-49502"]
comment = "CVE in ffmpeg-6.1.3 bundled by Lutris FHS env. Remove when Lutris updates."
until = "2026-07-01"
```

This approach ensures vulnix notifies you when a specific bundled version is no longer in use.

**Why this pattern:**
- vulnix matches by `pname`, so custom keys like `["spotify-ffmpeg"]` don't work
- Inline comments preserve the "separate section per consumer" intent
- VERSION MAP header makes it clear which consumer owns which version
- Per-CVE comments enable targeted cleanup when a consumer updates

**Whitelist best practices:**

| Practice | Why |
|----------|-----|
| Add to correct section | Keeps whitelist organized and maintainable |
| Document dep chain | Know when entry can be removed |
| Include version numbers | Clear what's affected vs what we have |
| Set `until` date for accepted risks | Forces periodic review |
| Explain the specific reason | Future you will thank present you |
| Review on flake updates | Whitelist may become unnecessary |

**Verify whitelist works:**
```bash
# CVE should not appear in results
vulnix --system | grep CVE-XXXX-XXXXX

# To see whitelisted CVEs
vulnix --system --show-whitelisted
```

### 6. Build and Verify

Test the fix before deploying.

**Build the configuration:**
```bash
nixos-rebuild build --flake .#<hostname>
```

**If build succeeds, apply:**
```bash
nixos-rebuild switch --flake .#<hostname>
```

**Verify CVE is resolved:**
```bash
vulnix --system | grep CVE-XXXX-XXXXX
# Should return no results
```

### 7. Document the Resolution

Update repository documentation:

**If patch was added:**
- Ensure patch file follows naming convention (`CVE-XXXX-XXXXX.patch`)
- Add comment in `modules/patches/<package>/default.nix` with CVE link
- Add import to `modules/patches/default.nix` (alphabetical order)
- Update `modules/patches/TOC.md` with entry for the new package

**If whitelisted:**
- Document in whitelist.toml with expiration date
- Add comment explaining risk assessment

## Guidelines

- **Verify before applying**: Always test patches build successfully
- **Document thoroughly**: Future maintainers need context
- **Set expiration dates**: Whitelists should be reviewed periodically
- **Check upstream first**: Don't duplicate work if nixpkgs has a fix pending
- **Prefer patches over whitelists**: Actual fixes are better than risk acceptance
- **Test in isolation**: Build before switching to catch issues early
