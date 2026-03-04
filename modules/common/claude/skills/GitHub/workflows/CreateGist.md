# CreateGist Workflow

This workflow guides you through creating a GitHub gist using `gh gist create`. It handles both gisting existing files and gisting content from the current conversation. No git repository is required.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Determine What to Gist

Identify the source of the gist content using this decision table:

| Situation | Action |
|-----------|--------|
| User specifies file paths | Use those paths directly with `gh gist create` |
| User wants to gist code/text from conversation | Write content to a temp file, use that with `gh gist create` |
| Unclear | Ask the user: "What would you like to gist — a file on disk or content from our conversation?" |

If writing conversation content to a temp file, choose a descriptive filename (e.g., `/tmp/snippet.py`, `/tmp/notes.md`) that reflects the content type.

### 2. Strip Personally Identifiable Information

Before uploading any files, read the PII stripping guide: `@./reference/pii-stripping.md`

Follow the "For files (gists, attachments)" process from that guide. Scan all files to be gisted and redact PII before proceeding.

**IMPORTANT:** Always perform this step — even if the gist is private. PII in gists is a persistent risk since visibility can be changed later.

### 3. Collect Gist Metadata

- **Description**: If the user provided a description, use it. Otherwise, generate a short description automatically based on the file contents (e.g., "Python script for parsing CSV data", "Nix configuration snippet for systemd services"). Always pass `--desc` — never omit it.
- **Visibility**: Default to **private/secret**. Ask: "Should this gist be public? (default: private)"

| Context | Visibility Override |
|---------|---------------------|
| Gist is being created to attach to or reference from a GitHub issue | **Must be public** — private gists are not visible to other issue participants. Inform the user: "Making this gist public since it will be linked from an issue." |
| Standalone gist | Default to private; ask user if they want public |

### 4. Construct the Command

Build the `gh gist create` command from the gathered information:

```bash
# Private gist (default) — single file
gh gist create --desc "Python script for parsing CSV data" path/to/file.py

# Private gist — multiple files
gh gist create --desc "Utility scripts for data processing" file1.py file2.py file3.py

# Public gist (e.g., for attaching to an issue)
gh gist create --public --desc "Reproduction script for login bug" snippet.py
```

Rules:
- Always include `--desc` — auto-generate a description from file contents if the user didn't provide one
- Add `--public` if the user asked for public, or if the gist is being linked from an issue
- List all file paths after the flags, separated by spaces
- If files were redacted in Step 2, use the redacted copies from `/tmp/`

### 5. Execute the Command

Run the constructed command exactly as built. Capture the output, which will include the gist URL.

### 6. Report Back to the User

Report the result clearly:

```
Gist created successfully.
URL: https://gist.github.com/<id>
Description: <description>
Visibility: private  (or: public)
```

If the command fails, show the error output and suggest common fixes:

| Error | Likely Cause | Suggestion |
|-------|--------------|------------|
| `not logged in` | gh auth not configured | Run `gh auth login` |
| `file not found` | Path is wrong | Verify the file path exists |
| `rate limit` | API limit hit | Wait a moment and retry |

## Guidelines

- **Always strip PII** — scan every file before uploading, even for private gists
- **Always include a description** — auto-generate one from file contents if the user doesn't provide one
- **Force public for issue-linked gists** — private gists are invisible to other issue participants
- **Default to private** for standalone gists — this is the security-conscious choice
- When writing conversation content to a temp file, clean it up after the gist is created if the user did not explicitly request to keep it
- For multiple files, confirm the full list with the user before executing
- Clean up redacted temp copies in `/tmp/` after the gist is created
