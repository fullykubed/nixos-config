# gh CLI Command Reference

Quick reference for the `gh` CLI commands used by GitHub skill workflows.

---

## gh issue create

Create a new issue in a GitHub repository.

```bash
gh issue create --title "TITLE" --body "BODY"
```

**Key flags:**

| Flag | Description |
|------|-------------|
| `--title "TEXT"` | Issue title (required) |
| `--body "TEXT"` | Issue body/description (required) |
| `--repo OWNER/REPO` | Target repository (defaults to the repo in the current directory) |

**Example:**
```bash
gh issue create \
  --title "Login button unresponsive on Safari" \
  --body "## Description\n\nThe login button does not respond..."
```

**Output:** The URL of the newly created issue.

---

## gh gist create

Create a GitHub gist from one or more files.

```bash
gh gist create [flags] [FILE...]
```

**Key flags:**

| Flag | Description |
|------|-------------|
| `--desc "TEXT"` | Description for the gist |
| `--public` | Make the gist public (default: secret/private) |

**Examples:**

```bash
# Private gist from a single file
gh gist create --desc "My snippet" path/to/file.py

# Private gist from multiple files
gh gist create --desc "Utils" file1.py file2.py

# Public gist
gh gist create --public --desc "Shared snippet" snippet.py

# No description
gh gist create path/to/file.py
```

**Output:** The URL of the newly created gist.

---

## gh repo clone

Clone a GitHub repository to your local machine.

```bash
gh repo clone OWNER/REPO [DESTINATION] [-- CLONE_FLAGS]
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `OWNER/REPO` | Repository to clone (also accepts full GitHub URL) |
| `DESTINATION` | Local directory name (defaults to the repo name) |
| `-- FLAGS` | Extra flags passed to `git clone` (separated by `--`) |

**Common git clone flags passed via `--`:**

| Flag | Description |
|------|-------------|
| `--branch <name>` | Check out a specific branch after cloning |
| `--depth=1` | Shallow clone (omits full history; useful for speed) |

**Examples:**

```bash
# Basic clone
gh repo clone octocat/hello-world

# Clone into a custom directory
gh repo clone octocat/hello-world my-local-dir

# Clone a specific branch
gh repo clone octocat/hello-world -- --branch feature-x

# Shallow clone
gh repo clone octocat/hello-world -- --depth=1

# Branch + shallow
gh repo clone octocat/hello-world -- --branch feature-x --depth=1

# Custom destination + branch
gh repo clone octocat/hello-world my-local-dir -- --branch feature-x
```

**Output:** Standard `git clone` output followed by the local path.

---

## gh api

Make authenticated requests to the GitHub REST or GraphQL API. Used by the FileIssue workflow to fetch contributing guidelines and issue templates.

```bash
gh api repos/OWNER/REPO/contents/PATH [flags]
```

**Key flags:**

| Flag | Description |
|------|-------------|
| `--jq QUERY` | Filter JSON output with a jq expression |

**Examples:**

```bash
# Fetch a file's content (base64-encoded)
gh api repos/octocat/hello-world/contents/.github/CONTRIBUTING.md --jq '.content' | base64 -d

# List directory contents
gh api repos/octocat/hello-world/contents/.github/ISSUE_TEMPLATE --jq '.[].name'
```

---

## gh repo view

Display repository metadata. Used by `claude-GitHub-repo-info` to gather context.

```bash
gh repo view --json owner,name,defaultBranchRef,url,visibility
```

**Key flags:**

| Flag | Description |
|------|-------------|
| `--json FIELDS` | Output specific fields as JSON (comma-separated) |

**Useful JSON fields:**

| Field | Description |
|-------|-------------|
| `owner` | Object with `login` key containing the repo owner |
| `name` | Repository name |
| `defaultBranchRef` | Object with `name` key containing the default branch |
| `url` | Full HTTPS URL of the repository |
| `visibility` | `PUBLIC` or `PRIVATE` |

---

## gh auth status

Check the current authentication state and identify the logged-in user.

```bash
gh auth status --json user -q '.user.login'
```

**Key flags:**

| Flag | Description |
|------|-------------|
| `--json FIELDS` | Output specific fields as JSON |
| `-q QUERY` | Filter JSON output with a jq expression |

**Output:** The GitHub username of the authenticated user, or an error if not logged in.
