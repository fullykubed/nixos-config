# IdentifyCVE Workflow

This workflow guides you through scanning a NixOS system for CVE vulnerabilities and triaging the results to identify real vulnerabilities vs false positives.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Get Vulnix Scan Results

Obtain vulnerability scan results either from the scheduled service or by running a manual scan.

**Option A: Check vulnix-scanner service results (preferred):**
```bash
# View most recent scan results from journal
journalctl -u vulnix-scanner.service -n 500 --no-pager

# Check when the service last ran
systemctl show vulnix-scanner.timer --property=LastTriggerUSec
```

**Option B: Run a manual scan:**
```bash
# Scan system packages (primary scan)
# Note: The whitelist is automatically applied via the vulnix wrapper
vulnix --system --json

# Optionally scan home-manager profile
vulnix ~/.local/state/nix/profiles/home-manager --json

# To see whitelisted CVEs as well:
vulnix --system --show-whitelisted --json
```

**Capture the output:**
- Save the JSON output for analysis
- Note the total number of CVEs reported
- Group by package for easier review

### 2. Parse and Organize Results

For each CVE in the scan results, extract:

| Field | Description |
|-------|-------------|
| CVE ID | The CVE identifier (e.g., CVE-2025-12345) |
| Package | The affected package name and version |
| CVSS Score | Severity score (if available) |
| Description | Brief description of the vulnerability |

**Prioritize by severity:**
1. Critical (9.0-10.0)
2. High (7.0-8.9)
3. Medium (4.0-6.9)
4. Low (0.1-3.9)

### 3. Triage Each CVE

For each CVE, determine if it's a real vulnerability or false positive.

**Common false positive patterns:**

| Pattern | How to Detect | Action |
|---------|---------------|--------|
| **Package name collision** | CVE is for different software with same name (e.g., Haskell `curl` vs CLI `curl`) | Check CVE description for ecosystem/language |
| **Distro-specific** | CVE mentions specific distro (Debian, Ubuntu, RHEL) | NixOS uses upstream packages, not distro patches |
| **Platform-specific** | CVE is for different OS (macOS, Windows) | Check if applicable to Linux |
| **Already fixed** | Version in CVE fixed-in is older than installed | Compare versions: `nix eval nixpkgs#<pkg>.version` |
| **Extension vs tool** | CVE is for IDE extension, not CLI tool | Read CVE description carefully |

**For each CVE, check:**

1. **Read the CVE description:**
   ```bash
   # Fetch from NVD
   WebFetch https://nvd.nist.gov/vuln/detail/CVE-XXXX-XXXXX
   ```

   **Or use Exa for broader context:**
   ```
   mcp__exa__web_search_exa with query: "CVE-XXXX-XXXXX description affected versions"
   ```

2. **Verify package identity:**
   - Does the CVE description match the actual package?
   - Is it for the correct language/ecosystem?
   - Is it for the correct platform?

3. **Check version status:**
   ```bash
   # Get installed version
   nix eval nixpkgs#<package>.version

   # Compare with fixed version in CVE
   ```

### 4. Document Findings

Create a triage summary for the user:

**For false positives:**
```
## False Positives

| CVE | Package | Reason |
|-----|---------|--------|
| CVE-XXXX-XXXXX | package-1.2.3 | Different software (Haskell vs CLI) |
| CVE-YYYY-YYYYY | package-2.0.0 | Already fixed in installed version |
```

**For real vulnerabilities:**
```
## Real Vulnerabilities

| CVE | Package | Severity | Attack Vector | Action Needed |
|-----|---------|----------|---------------|---------------|
| CVE-XXXX-XXXXX | package-1.2.3 | Critical (9.8) | Network | Patch required |
| CVE-YYYY-YYYYY | package-2.0.0 | High (7.5) | Local | Evaluate risk |
```

### 5. Prioritize and Recommend

Based on the triage, provide prioritized recommendations:

**Immediate action (Critical + Network-exploitable):**
- List CVEs requiring immediate patching
- Note any actively exploited vulnerabilities

**High priority (High severity):**
- List CVEs that should be addressed soon
- Consider attack vector and exposure

**Medium/Low priority:**
- List CVEs that can be scheduled
- Consider whitelisting with justification if risk is accepted

**Suggested next steps:**
- Recommend running ResolveCVE workflow for specific CVEs
- Suggest ReviewPatches workflow if patches already exist

## Guidelines

- **Be thorough**: Check every CVE, don't assume based on package name alone
- **Verify ecosystem**: Many false positives come from name collisions
- **Check versions carefully**: Compare semantic versions properly
- **Document reasoning**: Future reviewers need to understand triage decisions
- **Prioritize by risk**: Network-exploitable + Critical = highest priority
- **Consider context**: An unused feature vulnerability may be lower risk
