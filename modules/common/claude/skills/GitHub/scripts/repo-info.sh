#!/usr/bin/env bash
# Outputs current repository context as JSON.
# Used by GitHub skill workflows to gather environment information before
# performing operations.
#
# Output format (in a git repo):
#   {
#     "in_git_repo": true,
#     "owner": "user",
#     "repo": "repo-name",
#     "default_branch": "main",
#     "current_branch": "feature-x",
#     "visibility": "PUBLIC",
#     "url": "https://github.com/user/repo",
#     "authenticated_user": "username"
#   }
#
# Output format (not in a git repo):
#   {"in_git_repo": false, "owner": null, "repo": null,
#    "default_branch": null, "current_branch": null,
#    "visibility": null, "url": null, "authenticated_user": null}
#
# Errors are sent to stderr only. This script always exits 0.

set -euo pipefail

GH="@gh@"
GIT="@git@"
JAQ="@jaq@"

# Check if we are inside a git working tree.
if ! "$GIT" rev-parse --is-inside-work-tree &>/dev/null; then
  "$JAQ" -n '{
    in_git_repo: false,
    owner: null,
    repo: null,
    default_branch: null,
    current_branch: null,
    visibility: null,
    url: null,
    authenticated_user: null
  }'
  exit 0
fi

# Fetch repository metadata from gh. Fall back to an empty object if the
# command fails (e.g. the remote is not a GitHub repo or gh is not configured).
repo_json=$("$GH" repo view --json owner,name,defaultBranchRef,url,visibility 2>/dev/null || echo '{}')

# Current branch name (empty string if in a detached HEAD state).
current_branch=$("$GIT" branch --show-current 2>/dev/null || echo "")

# Authenticated GitHub username (empty string if not logged in).
auth_user=$("$GH" auth status --json user -q '.user.login' 2>/dev/null || echo "")

# Construct and emit the output JSON.
# shellcheck disable=SC2016  # jq uses $var syntax, not shell expansion
"$JAQ" -n \
  --argjson repo "$repo_json" \
  --arg branch "$current_branch" \
  --arg user "$auth_user" \
  '{
    in_git_repo: true,
    owner:          ($repo.owner.login  // null),
    repo:           ($repo.name         // null),
    default_branch: ($repo.defaultBranchRef.name // null),
    current_branch: (if $branch == "" then null else $branch end),
    visibility:     ($repo.visibility   // null),
    url:            ($repo.url          // null),
    authenticated_user: (if $user == "" then null else $user end)
  }'
