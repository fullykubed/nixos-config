# Stripping Personally Identifiable Information

Before publishing any content to GitHub — whether in an issue body, a gist file, or any other publicly or privately shared artifact — you MUST scan for and redact personally identifiable information (PII).

## PII Categories

| PII Type | Examples | Replacement |
|----------|----------|-------------|
| Real names | Full names in comments, author fields, git blame output | `REDACTED_NAME` |
| Email addresses | `user@example.com` in headers, configs, commit metadata | `REDACTED_EMAIL` |
| IP addresses | `192.168.1.100`, `10.0.0.1`, `2001:db8::1` in logs/configs | `REDACTED_IP` |
| Hostnames | Internal hostnames, FQDNs (e.g., `prod-db-01.internal.corp`) | `REDACTED_HOST` |
| File paths with usernames | `/home/john/`, `/Users/jane/`, `C:\Users\Bob\` | `/home/user/`, `/Users/user/`, `C:\Users\user\` |
| API keys / tokens | Strings that look like secrets, bearer tokens, AWS keys, private keys | `REDACTED_SECRET` |
| Phone numbers | Phone numbers in comments, config, or data files | `REDACTED_PHONE` |
| Physical addresses | Street addresses, postal codes in comments or data | `REDACTED_ADDRESS` |
| Account IDs | AWS account IDs, database user IDs, customer identifiers | `REDACTED_ID` |

## Process

### For files (gists, attachments)

1. Read each file to be uploaded
2. Scan for every PII category listed above
3. If PII is found:
   - Create a redacted copy in `/tmp/` preserving the original filename
   - Use the redacted copy instead of the original
   - Inform the user what was redacted: "Stripped PII before uploading: [list of redactions made]"
4. If no PII is found, proceed with the original file
5. Clean up redacted copies in `/tmp/` after upload completes

### For issue bodies and text content

1. Before constructing the `gh` command, review the full text of the issue body
2. Scan for every PII category listed above
3. If PII is found:
   - Replace inline using the replacement tokens above
   - Inform the user what was redacted before submitting
4. If no PII is found, proceed as-is

## Edge Cases

| Situation | Action |
|-----------|--------|
| PII is in a code sample the user explicitly wants to share | Ask the user: "This code contains [PII type]. Should I redact it or keep it as-is?" |
| Username in a file path is also the GitHub username | Still redact — the GitHub username is already public, but the local system path is not |
| Log output contains many IP addresses | Redact all of them; do not selectively keep some |
| Content is already clearly synthetic/example data | No redaction needed (e.g., `127.0.0.1`, `example.com`, `Jane Doe` in a test fixture) |
