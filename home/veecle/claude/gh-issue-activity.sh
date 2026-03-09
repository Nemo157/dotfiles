#!/usr/bin/env bash
# Fetch the current user's interactions with a GitHub issue.
# Outputs JSON with sections: metadata, comments.
#
# Usage: gh-issue-activity OWNER/REPO ISSUE_NUMBER

set -euo pipefail

usage() {
  echo "Usage: gh-issue-activity OWNER/REPO ISSUE_NUMBER" >&2
  exit 1
}

if [[ $# -ne 2 ]]; then
  usage
fi

repo="$1"
issue_number="$2"

user="$(gh api user --jq '.login')"

jq -n \
  --arg user "$user" \
  --slurpfile metadata <(
    gh api "repos/$repo/issues/$issue_number"
  ) \
  --slurpfile comments <(
    gh api "repos/$repo/issues/$issue_number/comments" --paginate
  ) \
  '{
    metadata: ($metadata[0] | {
      title: .title,
      body: .body,
      user: .user.login,
      state: .state,
      created_at: .created_at,
      closed_at: .closed_at,
      url: .html_url,
      labels: [.labels[].name]
    }),
    comments: ([$comments[] | .[] | select(.user.login == $user) | {created_at, body: (.body | .[0:200])}] | sort_by(.created_at))
  }'
