# ReviewPatches Workflow

This workflow guides you through reviewing existing CVE patches in the repository to verify they are still needed, properly applied, and up to date.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Inventory Existing Patches

List all CVE patches currently in the repository.

**Find patch files:**
```bash
# List all patch modules
ls -d modules/patches/*/

# List all .patch files across all packages
find modules/patches/ -name '*.patch' | sort

# Check which packages are imported
cat modules/patches/default.nix
```

**For each patch, extract:**
| Field | Source |
|-------|--------|
| CVE ID | Filename (`CVE-XXXX-XXXXX.patch`) |
| Package | Directory name under `modules/patches/<package>/` |
| Description | Comment in `modules/patches/<package>/default.nix` |
| Date Added | Git history |

**Note:** Patch files should follow the naming convention `CVE-XXXX-XXXXX.patch` (CVE ID only, no description suffix). This enables vulnix CVE patch auto-detection. See ResolveCVE.md for details.

### 2. Check Patch Status

For each patch, determine if it's still needed.

**Check if nixpkgs now includes the fix:**
```bash
# Get current nixpkgs version
nix eval nixpkgs#<package>.version

# Check if nixpkgs has the patch
WebFetch https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/by-name/<xx>/<package>/package.nix
```

**Check CVE status:**
```bash
# Verify CVE details and fixed versions
WebFetch https://nvd.nist.gov/vuln/detail/CVE-XXXX-XXXXX
```

**Or search for current status using Exa:**
```
# Check if CVE is now fixed in nixpkgs
mcp__exa__web_search_exa with query: "site:github.com/NixOS/nixpkgs CVE-XXXX-XXXXX merged"

# Check upstream fix status
mcp__exa__web_search_exa with query: "CVE-XXXX-XXXXX <package-name> fixed released"
```

**Decision matrix:**

| nixpkgs Version | CVE Fixed Version | Action |
|-----------------|-------------------|--------|
| >= fixed version | N/A | Patch may be removable |
| < fixed version | Known | Patch still needed |
| Unknown | Unknown | Research required |

### 3. Verify Patch Validity

For patches that are still needed, verify they apply correctly.

**Test patch application:**
```bash
# Build with the patch
nixos-rebuild build --flake .#<hostname>
```

**Check for patch conflicts:**
- Patches may fail if upstream code changed
- Fuzz warnings indicate partial matches
- Rejected hunks indicate breaking changes

**If patch fails:**
1. Check if upstream released a new fix
2. Update patch to match current source
3. Document changes in commit message

### 4. Review Whitelist Entries

Review whitelist entries for expiration and continued validity.

**Check whitelist:**
```bash
cat modules/common/vulnix-scanner/whitelist.toml
```

Note: The whitelist is automatically applied when running `vulnix` via the system wrapper.

**For each entry, verify:**
| Check | Action |
|-------|--------|
| `until` date passed? | Re-evaluate risk or remove |
| CVE still applies? | Check if still relevant |
| Justification valid? | Confirm reasoning still holds |

### 5. Generate Status Report

Create a comprehensive report of patch status.

**Report format:**
```markdown
## CVE Patch Review Summary

### Active Patches (Still Needed)
| CVE | Package | Reason Still Needed |
|-----|---------|---------------------|
| CVE-XXXX-XXXXX | pkg-1.2.3 | nixpkgs has 1.2.2, fix in 1.2.4 |

### Patches to Remove (Now in nixpkgs)
| CVE | Package | nixpkgs Version |
|-----|---------|-----------------|
| CVE-YYYY-YYYYY | pkg-2.0.0 | 2.1.0 includes fix |

### Patches Needing Update
| CVE | Package | Issue |
|-----|---------|-------|
| CVE-ZZZZ-ZZZZZ | pkg-3.0.0 | Patch has fuzz warnings |

### Whitelist Review
| CVE | Package | Status | Action |
|-----|---------|--------|--------|
| CVE-AAAA-AAAAA | pkg-4.0.0 | Expired | Re-evaluate |
```

### 6. Apply Recommendations

Based on the review, take appropriate actions:

**For removable patches:**
1. Remove the package directory from `modules/patches/<package>/`
2. Remove the import from `modules/patches/default.nix`
3. Remove the entry from `modules/patches/TOC.md`
4. Rebuild and verify CVE is still resolved (by nixpkgs)
5. Commit with message explaining removal

**For patches needing updates:**
1. Fetch updated patch from upstream
2. Replace old patch file in `modules/patches/<package>/`
3. Update comment in `modules/patches/<package>/default.nix`
4. Rebuild and test

**For expired whitelists:**
1. Re-run vulnix to check if CVE still reported
2. Either renew with new expiration or remove
3. Document decision

## Guidelines

- **Review regularly**: Patches should be reviewed when updating flake inputs
- **Remove when possible**: Local patches add maintenance burden
- **Document removals**: Commit messages should explain why patch was removed
- **Track upstream**: Subscribe to nixpkgs PRs for packages you've patched
- **Test after changes**: Always rebuild after modifying patches
- **Keep whitelist current**: Expired entries should be re-evaluated, not ignored
