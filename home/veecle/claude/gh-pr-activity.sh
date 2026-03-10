#!/usr/bin/env bash
# Fetch the current user's interactions with a GitHub PR.
# Outputs JSON with sections: metadata, reviews, review_comments, commits,
# and all_reviews (all reviewers, not just current user).
#
# Usage: gh-pr-activity OWNER/REPO PR_NUMBER

set -euo pipefail

usage() {
  echo "Usage: gh-pr-activity OWNER/REPO PR_NUMBER" >&2
  exit 1
}

if [[ $# -ne 2 ]]; then
  usage
fi

repo="$1"
pr_number="$2"

user="$(gh api user --jq '.login')"

jq -n \
  --arg user "$user" \
  --slurpfile metadata <(
    gh api "repos/$repo/pulls/$pr_number"
  ) \
  --slurpfile reviews <(
    gh api "repos/$repo/pulls/$pr_number/reviews" --paginate
  ) \
  --slurpfile comments <(
    gh api "repos/$repo/pulls/$pr_number/comments" --paginate
  ) \
  --slurpfile commits <(
    gh api "repos/$repo/pulls/$pr_number/commits" --paginate
  ) \
  '{
    metadata: ($metadata[0] | {
      title: .title,
      body: .body,
      user: .user.login,
      state: .state,
      created_at: .created_at,
      merged_at: .merged_at,
      merged_by: (.merged_by.login // null),
      url: .html_url
    }),
    reviews: ([$reviews[] | .[] | select(.user.login == $user) | {submitted_at, state, body}] | sort_by(.submitted_at)),
    all_reviews: (
      [$reviews[] | .[] | select(.user.login != "claude") | {login: .user.login, state, submitted_at}]
      | group_by(.login)
      | map(sort_by(.submitted_at) | last)
      | sort_by(.login)
    ),
    review_comments: ([$comments[] | .[] | select(.user.login == $user) | {created_at, body: (.body | .[0:200])}] | sort_by(.created_at)),
    commits: ([$commits[] | .[] | select(.author.login == $user or .committer.login == $user) | {date: .commit.author.date, message: (.commit.message | split("\n")[0])}] | sort_by(.date))
  }'
