# Report Formats

Output formats for Step 9 of the AutoDeployFix workflow.

## Build Succeeded

```
=============================================================================
BUILD SUCCESS
=============================================================================

NixOS configuration built successfully for: <hostname>

Fix cycles: <N>

Fixes applied:
  1. [<commit_hash>] <commit_subject>
     Error: <error_type>
     Fix: <fix_description>

  2. [<commit_hash>] <commit_subject>
     Error: <error_type>
     Fix: <fix_description>

  ...

Next steps:
  Run `un` to activate the configuration
  or
  Run `nixos-rebuild switch --flake .#<hostname>` to switch to the new config
=============================================================================
```

## Build Failed (Exhausted Fixes)

```
=============================================================================
BUILD FAILED - No More Fix Strategies Available
=============================================================================

NixOS configuration build failed for: <hostname>

Fix cycles attempted: <N>

Fixes applied:
  1. [<commit_hash>] <commit_subject>
     Error: <error_type>
     Fix: <fix_description>

  ...

Final error:
<error_output_last_100_lines>

Why stopped:
  [ ] Exhausted all fix strategies for this error type
  [ ] Circular fix detected (same error after applying same fix category)
  [ ] Unknown error with no research results

Suggested manual investigation:
  1. Review the full build log: nix log <derivation-path>
  2. Search nixpkgs issues: https://github.com/NixOS/nixpkgs/issues
  3. Check upstream package issues: <upstream-repo-url>
  4. Review recent commits that may have introduced the issue
  5. Consider rolling back flake inputs if this occurred after an update

For further assistance, provide the error output above.
=============================================================================
```
