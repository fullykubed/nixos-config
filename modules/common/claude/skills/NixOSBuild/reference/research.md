# Research: Online Search for Unfamiliar Errors

When the build error is unfamiliar or doesn't match known patterns, use the Exa MCP tools to search for solutions online.

## Search Strategy

Launch all four searches as parallel subagents using the Task tool (`subagent_type: "prd-researcher"`), then synthesize the combined results:

1. **Error message search:**
   ```
   mcp__exa__web_search_exa: "<error message> nixos"
   ```

2. **Package + error type search:**
   ```
   mcp__exa__web_search_exa: "<package name> <error type> nixpkgs"
   ```

3. **Code examples search:**
   ```
   mcp__exa__get_code_context_exa: "<package name> <error type> fix nix"
   ```

4. **Nixpkgs issues and PRs search:**
   ```
   mcp__exa__web_search_exa: "site:github.com/NixOS/nixpkgs <package name> <error>"
   ```

Send all four Task tool calls in a single message so they run concurrently. Once all results are returned, synthesize the findings and determine a fix strategy.

## Tips

- Quote the most specific part of the error message for better results
- Include the package version if the error is version-specific
- Check nixpkgs PRs — someone may have already submitted a fix that hasn't been merged
- Look for `overrideAttrs` or `override` patterns in search results — these translate directly to `patches/default.nix`

## When to Give Up

If 2-3 search attempts yield nothing actionable, stop researching and report the failure.
