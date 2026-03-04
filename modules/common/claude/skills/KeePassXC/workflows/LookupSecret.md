# LookupSecret Workflow

Retrieve a secret from KeePassXC via the FDO Secret Service.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Search for the Entry

If you know the exact title, skip to step 2.

Otherwise, run `claude-KeePassXC-search` to list all available entries:

```bash
claude-KeePassXC-search
```

If a search term was provided, pass it to filter results:

```bash
claude-KeePassXC-search <term>
```

The output is JSON with entry titles and attributes (never passwords). Identify the correct entry from the results.

### 2. Look Up the Secret

Once you have the entry title, retrieve the password:

```bash
claude-KeePassXC-lookup <exact-entry-title>
```

This returns a JSON object with a `secret` field containing the password value.

| Situation | Action |
|-----------|--------|
| Lookup succeeds | Use the secret value from the JSON response |
| Lookup fails with "not found" | Re-run `claude-KeePassXC-search` to check the exact title and retry |
| Lookup fails with "Secret Service" error | KeePassXC is not running or database is locked — inform the user |

### 3. Use the Secret

Use the retrieved value for the intended purpose (set as env var, pass to API, write to config, etc.).

### 4. Report Outcome

Tell the user you successfully retrieved the credential by name (not value). Example: "Retrieved the GitHub API token from KeePassXC."

## Guidelines

- NEVER include secret values in text responses to the user
- NEVER commit secrets to version control
- NEVER echo, log, or print secret values
- If writing a secret to a file, ensure appropriate permissions (0600)
- Always prefer passing secrets via environment variables or stdin over writing to files
