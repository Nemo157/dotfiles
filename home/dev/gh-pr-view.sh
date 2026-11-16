# Browse the timeline of a GitHub PR: entries on the left, details of the
# selected entry (review bodies, threads with their diff, push diffs,
# force-push range-diffs) on the right.
#
# Usage: gh-pr-view [<number> | <url> | <branch>]
#
# Without an argument the PR is found from the current branch or, when that
# fails (e.g. under jj), from the PRs containing recent HEAD commits.

self="$(realpath "${BASH_SOURCE[0]}")"

usage() {
  echo "usage: gh-pr-view [<number> | <url> | <branch>]"
}

die() {
  echo "gh-pr-view: $*" >&2
  exit 1
}

dim() {
  printf '\e[2m%s\e[0m\n' "$*"
}

# --- fetching ---------------------------------------------------------------

query_timeline() {
  cat <<'EOF'
query($owner: String!, $name: String!, $number: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      number title url body state isDraft createdAt
      author { login }
      baseRefName headRefName baseRefOid headRefOid
      timelineItems(first: 100, after: $endCursor, itemTypes: [
        PULL_REQUEST_COMMIT, HEAD_REF_FORCE_PUSHED_EVENT, PULL_REQUEST_REVIEW,
        ISSUE_COMMENT, MERGED_EVENT, CLOSED_EVENT, REOPENED_EVENT,
        READY_FOR_REVIEW_EVENT, CONVERT_TO_DRAFT_EVENT
      ]) {
        pageInfo { hasNextPage endCursor }
        nodes {
          __typename
          ... on PullRequestCommit {
            commit {
              oid abbreviatedOid messageHeadline committedDate
              author { user { login } name }
              parents(first: 1) { nodes { oid } }
            }
          }
          ... on HeadRefForcePushedEvent {
            actor { login } createdAt
            beforeCommit { oid abbreviatedOid }
            afterCommit { oid abbreviatedOid }
          }
          ... on PullRequestReview { id author { login } state body submittedAt createdAt url }
          ... on IssueComment { author { login } body createdAt url }
          ... on MergedEvent { actor { login } createdAt }
          ... on ClosedEvent { actor { login } createdAt }
          ... on ReopenedEvent { actor { login } createdAt }
          ... on ReadyForReviewEvent { actor { login } createdAt }
          ... on ConvertToDraftEvent { actor { login } createdAt }
        }
      }
    }
  }
}
EOF
}

query_threads() {
  cat <<'EOF'
query($owner: String!, $name: String!, $number: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          isResolved isOutdated path line startLine originalLine originalStartLine
          resolvedBy { login }
          comments(first: 100) {
            nodes {
              author { login } body createdAt url diffHunk
              pullRequestReview { id }
            }
          }
        }
      }
    }
  }
}
EOF
}

# Turns the raw GraphQL pages into { repo, pr, entries: [...] }, one entry per
# line item in the timeline, sorted by time, with consecutive reviews,
# comments and threads by one user condensed into a group.
prog_normalize() {
  cat <<'EOF'
def actor: .login // "ghost";
def groupable: .kind == "review" or .kind == "comment" or .kind == "thread";

# Orders a group's items with each review followed by its own threads, and
# takes its time, state and url from the items.
def group_finish:
  .items as $items
  | [ $items[] | select(.kind == "review") ] as $reviews
  | ($reviews | map(.id)) as $ids
  | .items = [ $items[]
               | select(.kind != "thread" or (.review as $r | $ids | any(.[]; . == $r) | not))
               | ., ( select(.kind == "review")
                      | .id as $id
                      | $items[]
                      | select(.kind == "thread" and .review == $id) ) ]
  | .at = ($items | map(.at) | max)
  | .state = ($reviews[-1].state // null)
  | .url = ($reviews[-1].url // $items[0].url);

# Condenses runs of reviews, comments and threads by the same user into a
# single group entry.
def condense:
  reduce .[] as $e ([];
    if length > 0 and ($e | groupable) and .[-1].actor == $e.actor
       and (.[-1] | (groupable or .kind == "group"))
    then (length - 1) as $i
      | .[$i] |= ( if .kind == "group" then .items += [$e]
                   else { kind: "group", actor: .actor, items: [., $e] } end )
    else . + [$e] end)
  | map(if .kind == "group" then group_finish else . end);

($t[0] | map(.data.repository.pullRequest)) as $pages
| $pages[0] as $pr
| ($pr.url | sub("/pull/[0-9]+$"; "")) as $repo_url
| [ $th[0][].data.repository.pullRequest.reviewThreads.nodes[]
    | select((.comments.nodes | length) > 0) ] as $threads
| ( reduce ($pages[].timelineItems.nodes[]) as $n ([];
      if $n.__typename == "PullRequestCommit" then
        ( $n.commit
          | { oid,
              short: .abbreviatedOid,
              headline: .messageHeadline,
              parent: (.parents.nodes[0].oid // null),
              at: .committedDate,
              actor: (.author.user.login // .author.name // "?"),
              url: "\($pr.url)/commits/\(.oid)" } ) as $c
        # GitHub doesn't expose push grouping, adjacent commits are the best
        # available heuristic
        | if length > 0 and .[-1].kind == "push" then
            (length - 1) as $i
            | .[$i].commits += [$c]
            | .[$i] += { at: $c.at, actor: $c.actor, url: $c.url }
          else
            . + [{ kind: "push", at: $c.at, actor: $c.actor, url: $c.url, commits: [$c] }]
          end
      elif $n.__typename == "HeadRefForcePushedEvent" then
        . + [{ kind: "force",
               at: $n.createdAt,
               actor: ($n.actor | actor),
               before: $n.beforeCommit.oid,
               after: $n.afterCommit.oid,
               before_short: ($n.beforeCommit.abbreviatedOid // "?"),
               after_short: ($n.afterCommit.abbreviatedOid // "?"),
               url: "\($repo_url)/compare/\($n.beforeCommit.oid)..\($n.afterCommit.oid)" }]
      elif $n.__typename == "PullRequestReview" then
        # empty COMMENTED reviews are just containers for inline threads,
        # which get their own entries
        if $n.state == "PENDING"
           or ($n.state == "COMMENTED" and (($n.body // "") | test("\\S") | not))
        then .
        else
          . + [{ kind: "review",
                 id: $n.id,
                 at: ($n.submittedAt // $n.createdAt),
                 actor: ($n.author | actor),
                 state: $n.state,
                 body: $n.body,
                 url: $n.url,
                 threads: [ $threads[]
                            | select(any(.comments.nodes[]; .pullRequestReview.id == $n.id))
                            | "\(.path):\(.line // .originalLine // "?")" ] }]
        end
      elif $n.__typename == "IssueComment" then
        . + [{ kind: "comment", at: $n.createdAt, actor: ($n.author | actor),
               body: $n.body, url: $n.url }]
      else
        . + [{ kind: "event", at: $n.createdAt, actor: ($n.actor | actor), url: $pr.url,
               text: ({ MergedEvent: "merged",
                        ClosedEvent: "closed",
                        ReopenedEvent: "reopened",
                        ReadyForReviewEvent: "marked ready for review",
                        ConvertToDraftEvent: "converted to draft" }[$n.__typename]
                      // $n.__typename) }]
      end) ) as $timeline
| ( $threads
    | map(.comments.nodes as $cs
          | { kind: "thread",
              at: $cs[0].createdAt,
              actor: ($cs[0].author | actor),
              path,
              line: (.line // .originalLine),
              start_line: (.startLine // .originalStartLine),
              resolved: .isResolved,
              outdated: .isOutdated,
              resolved_by: (.resolvedBy.login // null),
              review: ($cs[0].pullRequestReview.id // null),
              hunk: $cs[0].diffHunk,
              url: $cs[0].url,
              comments: [ $cs[] | { actor: (.author | actor), at: .createdAt, body } ] }) ) as $thread_entries
| { repo: $repo,
    pr: ($pr | del(.timelineItems)),
    entries: ( [{ kind: "open", at: $pr.createdAt, actor: ($pr.author | actor),
                  title: $pr.title, body: $pr.body, url: $pr.url }]
               + ($timeline + $thread_entries | sort_by(.at) | condense) ) }
EOF
}

fetch() {
  local dir=$1 owner name number
  read -r owner name number <"$dir/target"

  # explicit `|| return`s as this runs under `&&` for --refresh, where
  # `set -e` is disabled, and a failure must not clobber the existing data
  gh api graphql --paginate --slurp \
    -f query="$(query_timeline)" -f owner="$owner" -f name="$name" -F number="$number" \
    >"$dir/timeline.json" || return
  gh api graphql --paginate --slurp \
    -f query="$(query_threads)" -f owner="$owner" -f name="$name" -F number="$number" \
    >"$dir/threads.json" || return

  jq -n \
    --slurpfile t "$dir/timeline.json" \
    --slurpfile th "$dir/threads.json" \
    --arg repo "$owner/$name" \
    "$(prog_normalize)" >"$dir/data.json.new" || return
  mv "$dir/data.json.new" "$dir/data.json"
}

# --- left pane --------------------------------------------------------------

# NUL-terminated multi-line items: "<index>\t<header>[\n<detail>...]"
prog_list() {
  cat <<'EOF'
def colour($c): "\u001b[\($c)m" + . + "\u001b[0m";
def when: fromdateiso8601 | strflocaltime("%m-%d %H:%M");
def trunc($n): if length > $n then .[:$n - 1] + "…" else . end;
def lines($k):
  (. // "") | gsub("\r"; "") | split("\n")
  | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0)) | .[:$k];
def count($n; $one; $many): "\($n) \(if $n == 1 then $one else $many end)";
def review_state:
  { APPROVED: ["✓", "32", "approved"],
    CHANGES_REQUESTED: ["✗", "31", "requested changes"],
    COMMENTED: ["•", "33", "reviewed"],
    DISMISSED: ["⊘", "90", "review dismissed"]
  }[.] // ["?", "90", ascii_downcase];

.entries
| to_entries[]
| .key as $i
| .value as $e
| ($e.actor | colour("1")) as $who
| ( if $e.kind == "open" then
      [ ("●" | colour("32")) + " \($who) opened", [$e.title] ]
    elif $e.kind == "push" then
      [ ("⇡" | colour("34")) + " \($who) pushed " + count($e.commits | length; "commit"; "commits"),
        ( $e.commits
          | map("\(.short) \(.headline)")
          | if length > 2 then [.[0], "… and \(length - 1) more"] else . end ) ]
    elif $e.kind == "force" then
      [ ("⇄" | colour("35")) + " \($who) force-pushed "
          + ("\($e.before_short) → \($e.after_short)" | colour("2")),
        [] ]
    elif $e.kind == "review" then
      ($e.state | review_state) as [$sym, $c, $verb]
      | [ ($sym | colour($c)) + " \($who) " + ($verb | colour($c)),
          ($e.body | lines(1))
          + (($e.threads | length) | if . > 0 then [count(.; "thread"; "threads")] else [] end) ]
    elif $e.kind == "comment" then
      [ ("◇" | colour("36")) + " \($who) commented", ($e.body | lines(2)) ]
    elif $e.kind == "group" then
      ( if $e.state then $e.state | review_state else ["◇", "36", "commented"] end ) as [$sym, $c, $verb]
      | ($e.items | map(select(.kind == "thread")) | length) as $threads
      | ($e.items | map(select(.kind == "comment")) | length) as $comments
      | [ ($sym | colour($c)) + " \($who) " + ($verb | colour($c))
          + ( [ (if $threads > 0 then count($threads; "thread"; "threads") else empty end),
                (if $comments > 0 then count($comments; "comment"; "comments") else empty end) ]
              | if length > 0 then "  " + (join(", ") | colour("2")) else "" end ),
          [ $e.items[] | if .kind == "thread" then .comments[0].body else .body end | lines(1)[] ][:2] ]
    elif $e.kind == "thread" then
      [ ("»" | colour("33")) + " \($who) on " + ("\($e.path):\($e.line // "?")" | colour("36"))
          + ( if $e.resolved then "  " + ("✓ resolved" | colour("32"))
              elif $e.outdated then "  " + ("outdated" | colour("90"))
              else "" end ),
        ($e.comments[0].body | lines(1))
        + ((($e.comments | length) - 1) | if . > 0 then [count(.; "reply"; "replies")] else [] end) ]
    else
      [ ("◆" | colour("35")) + " \($who) \($e.text)", [] ]
    end ) as [$head, $details]
| "\($i)\t" + ($e.at | when | colour("2")) + "  " + $head
  + ($details | map("\n" + (" " * 15) + (trunc($w) | colour("2"))) | join(""))
  + "\u0000"
EOF
}

list() {
  local dir=$1 cols w
  cols=${FZF_COLUMNS:-$(tput cols 2>/dev/null || echo 100)}
  # list pane is 40%, minus the detail indent and pointer
  w=$((cols * 40 / 100 - 17))
  if ((w < 20)); then w=20; fi
  jq -j --argjson w "$w" "$(prog_list)" "$dir/data.json"
}

# --- right pane -------------------------------------------------------------

md() {
  CLICOLOR_FORCE=1 glow -s "${GLAMOUR_STYLE:-dark}" -w "$cols" -
}

delta_diff() {
  delta --paging=never --width "$cols"
}

# Make sure a commit exists locally, fetching it by oid if needed. Only
# fetches when origin is the PR's repo, otherwise the caller falls back to
# the GitHub API.
have_commit() {
  local dir=$1 oid=$2
  git cat-file -e "$oid^{commit}" 2>/dev/null || {
    [[ -e $dir/origin-matches ]] &&
      git fetch --quiet --no-tags --no-write-fetch-head origin "$oid" 2>/dev/null
  }
}

diff_range() {
  local dir=$1 a=$2 b=$3 repo cache
  cache="$dir/cache/diff-$a-$b"
  if [[ ! -s $cache ]]; then
    if have_commit "$dir" "$a" && have_commit "$dir" "$b"; then
      git diff --no-color --no-ext-diff "$a" "$b" >"$cache.tmp"
    else
      repo=$(jq -r .repo "$dir/data.json")
      gh api -H 'Accept: application/vnd.github.diff' "repos/$repo/compare/$a...$b" >"$cache.tmp"
    fi && mv "$cache.tmp" "$cache"
  fi
  cat "$cache" 2>/dev/null || dim "(diff unavailable)"
}

range_diff() {
  local dir=$1 before=$2 after=$3 base=$4 old new
  if ! have_commit "$dir" "$before" || ! have_commit "$dir" "$after" ||
    ! have_commit "$dir" "$base"; then
    return 1
  fi
  old=$(git merge-base "$base" "$before") || return 1
  new=$(git merge-base "$base" "$after") || return 1
  dim "git range-diff ${old:0:7}..${before:0:7} ${new:0:7}..${after:0:7}"
  echo
  git range-diff --color=always "$old..$before" "$new..$after"
}

heading() {
  jq -r '
    def colour($c): "\u001b[\($c)m" + . + "\u001b[0m";
    def plural($n; $w): "\($n) \($w)\(if $n == 1 then "" else "s" end)";
    { APPROVED: "approved",
      CHANGES_REQUESTED: "requested changes",
      COMMENTED: "reviewed",
      DISMISSED: "review dismissed" } as $states
    | ( if .kind == "open" then "opened the pull request"
        elif .kind == "push" then "pushed \(plural(.commits | length; "commit"))"
        elif .kind == "force" then "force-pushed \(.before_short) → \(.after_short)"
        elif .kind == "review" then $states[.state] // (.state | ascii_downcase)
        elif .kind == "group" then
          if .state then $states[.state] // (.state | ascii_downcase) else "commented" end
        elif .kind == "comment" then "commented"
        elif .kind == "thread" then "commented on \(.path):\(.line // "?")"
        else .text end ) as $verb
    | (.actor | colour("1")) + " " + $verb + "  "
        + (.at | fromdateiso8601 | strflocaltime("%Y-%m-%d %H:%M") | colour("2")),
      (.url // "" | colour("2;4")),
      ("─" * 40 | colour("2")),
      ""
  ' <<<"$1"
}

render_thread() {
  local entry=$1 hunk status
  # GitHub sends the whole hunk up to the commented line, keep the selected
  # lines plus a little context, with a header adjusted for the dropped lines
  hunk=$(jq -r '
    select((.hunk // "") != "")
    | (.hunk | split("\n")) as $all
    | ($all | map(select(startswith("@@") | not))) as $lines
    | ( if .line != null and .start_line != null
        then ([.line - .start_line + 1, 1] | max) else 1 end ) as $selected
    | ([$lines | length, $selected + 3] | min) as $keep
    | $lines[:($lines | length) - $keep] as $dropped
    | ($all[0] | capture("^@@ -(?<old>[0-9]+)(,[0-9]+)? \\+(?<new>[0-9]+)")) as $start
    | (($start.old | tonumber) + ($dropped | map(select(startswith("+") | not)) | length)) as $old
    | (($start.new | tonumber) + ($dropped | map(select(startswith("-") | not)) | length)) as $new
    | "--- a/\(.path)\n+++ b/\(.path)\n@@ -\($old) +\($new) @@\n"
      + ($lines[($lines | length) - $keep:] | join("\n"))
  ' <<<"$entry") || hunk=
  if [[ -n $hunk ]]; then
    delta_diff <<<"$hunk"
    echo
  fi

  status=$(jq -r '
    if .resolved then "✓ resolved" + (if .resolved_by then " by \(.resolved_by)" else "" end)
    elif .outdated then "outdated"
    else empty end
  ' <<<"$entry")
  if [[ -n $status ]]; then
    dim "$status"
    echo
  fi

  jq -r '
    .comments
    | map("**\(.actor)** · \(.at | fromdateiso8601 | strflocaltime("%m-%d %H:%M"))\n\n\(.body)")
    | join("\n\n---\n\n")
  ' <<<"$entry" | md
}

render_push() {
  local dir=$1 entry=$2 parent head
  jq -r '.commits[] | "\u001b[33m\(.short)\u001b[0m \(.headline)"' <<<"$entry"
  echo
  parent=$(jq -r '.commits[0].parent // empty' <<<"$entry")
  head=$(jq -r '.commits[-1].oid' <<<"$entry")
  if [[ -n $parent ]]; then
    diff_range "$dir" "$parent" "$head" | delta_diff
  fi
}

render_force() {
  local dir=$1 entry=$2 before after base cache
  before=$(jq -r '.before // empty' <<<"$entry")
  after=$(jq -r '.after // empty' <<<"$entry")
  if [[ -z $before || -z $after ]]; then
    dim "(commits are no longer available on GitHub)"
    return
  fi

  base=$(jq -r .pr.baseRefOid "$dir/data.json")
  cache="$dir/cache/range-$before-$after"
  if [[ ! -s $cache ]] && range_diff "$dir" "$before" "$after" "$base" >"$cache.tmp"; then
    mv "$cache.tmp" "$cache"
  fi

  if [[ -s $cache ]]; then
    cat "$cache"
  else
    dim "(commits not available locally, showing GitHub's three-dot compare)"
    echo
    diff_range "$dir" "$before" "$after" | delta_diff
  fi
}

# One line introducing an item within a group.
subheading() {
  jq -r '
    def colour($c): "\u001b[\($c)m" + . + "\u001b[0m";
    ( if .kind == "review" then
        ( { APPROVED: ["✓", "32", "approved"],
            CHANGES_REQUESTED: ["✗", "31", "requested changes"],
            COMMENTED: ["•", "33", "reviewed"],
            DISMISSED: ["⊘", "90", "review dismissed"] }[.state]
          // ["?", "90", (.state | ascii_downcase)] ) as [$sym, $c, $verb]
        | "\($sym) \($verb)" | colour("1;\($c)")
      elif .kind == "comment" then "◇ commented" | colour("1;36")
      elif .kind == "thread" then "» \(.path):\(.line // "?")" | colour("1;33")
      else .kind end )
    + "  " + (.at | fromdateiso8601 | strflocaltime("%m-%d %H:%M") | colour("2")),
    ""
  ' <<<"$1"
}

# Shows every item of a group in full, the review thread lists skip the
# threads that are shown anyway.
render_group() {
  local dir=$1 entry=$2 shown n i item
  shown=$(jq -c '[.items[] | select(.kind == "thread") | "\(.path):\(.line // "?")"]' <<<"$entry")
  n=$(jq '.items | length' <<<"$entry")
  for ((i = 0; i < n; i++)); do
    item=$(jq -c --argjson i "$i" '.items[$i]' <<<"$entry")
    if ((i > 0)); then
      echo
      dim "$(printf '┄%.0s' {1..40})"
      echo
    fi
    subheading "$item"
    render_body "$dir" "$item" "$shown"
  done
}

render_body() {
  local dir=$1 entry=$2 shown=${3:-[]}
  case $(jq -r .kind <<<"$entry") in
  open) jq -r '"# \(.title)\n\n\(.body // "")"' <<<"$entry" | md ;;
  comment) jq -r '.body // ""' <<<"$entry" | md ;;
  review)
    jq -r --argjson shown "$shown" '
      (.body // "") as $body
      | (.threads - $shown) as $threads
      | $body
        + ( if ($threads | length) > 0
            then (if ($body | test("\\S")) then "\n\n" else "" end)
              + "**Threads:**\n\n" + ($threads | map("- `\(.)`") | join("\n"))
            else "" end )
    ' <<<"$entry" | md
    ;;
  thread) render_thread "$entry" ;;
  push) render_push "$dir" "$entry" ;;
  force) render_force "$dir" "$entry" ;;
  group) render_group "$dir" "$entry" ;;
  esac
}

render() {
  local dir=$1 idx=$2 entry
  cols=${FZF_PREVIEW_COLUMNS:-80}
  entry=$(jq -c --argjson i "$idx" '.entries[$i]' "$dir/data.json")

  heading "$entry"
  render_body "$dir" "$entry"
}

open_entry() {
  local dir=$1 idx=$2 url
  url=$(jq -r --argjson i "$idx" '.entries[$i].url // .pr.url' "$dir/data.json")
  if command -v xdg-open >/dev/null; then
    xdg-open "$url" >/dev/null 2>&1
  elif command -v open >/dev/null; then
    open "$url"
  fi
}

# --- main -------------------------------------------------------------------

# Find the PR from the PRs containing HEAD or its parent, works under jj
# where the git HEAD is detached.
detect() {
  local sha url
  while read -r sha; do
    url=$(gh api "repos/{owner}/{repo}/commits/$sha/pulls" \
      --jq '(map(select(.state == "open")) + .)[0].html_url // empty' 2>/dev/null) || continue
    if [[ -n $url ]]; then
      echo "$url"
      return
    fi
  done < <(git log --format=%H -n 2 2>/dev/null)
  return 1
}

main() {
  local url owner name number header

  if [[ $# -gt 0 ]]; then
    url=$(gh pr view "$1" --json url --jq .url) || exit 1
  else
    url=$(gh pr view --json url --jq .url 2>/dev/null) || url=$(detect) ||
      die "no PR found for the current changes, pass one explicitly"
  fi
  [[ $url =~ ^https://[^/]+/([^/]+)/([^/]+)/pull/([0-9]+) ]] || die "unexpected PR url: $url"
  owner=${BASH_REMATCH[1]} name=${BASH_REMATCH[2]} number=${BASH_REMATCH[3]}

  dir=$(mktemp -d "${TMPDIR:-/tmp}/gh-pr-view.XXXXXX")
  trap 'rm -rf "$dir"' EXIT
  mkdir "$dir/cache"
  printf '%s %s %s\n' "$owner" "$name" "$number" >"$dir/target"

  # only fetch missing commits from origin when it is the PR's repo
  local origin
  origin=$(git remote get-url origin 2>/dev/null) || origin=
  origin=${origin%/}
  origin=${origin%.git}
  if [[ ${origin,,} == *[:/]"${owner,,}/${name,,}" ]]; then
    touch "$dir/origin-matches"
  fi

  echo "fetching $owner/$name#$number…" >&2
  fetch "$dir"

  header=$(jq -r '
    def colour($c): "\u001b[\($c)m" + . + "\u001b[0m";
    .pr
    | ("#\(.number) \(.title)" | colour("1")),
      ( "\(.author.login // "ghost") · \(.headRefName) → \(.baseRefName) · "
        + (if .isDraft then "draft" else (.state | ascii_downcase) end) ),
      ("j/k: move  J/K: move list  ctrl-w: switch pane  enter: open  r: refresh  q: quit"
        | colour("2"))
  ' "$dir/data.json")

  # Which pane j/k drive is kept in the preview label: the modal bindings
  # check it to pick the list or preview action, ctrl-w/tab flip it.
  local q_self q_dir list_label=' list ' preview_label=' ▶ preview '
  printf -v q_self '%q' "$self"
  printf -v q_dir '%q' "$dir"
  local in_preview="[[ \$FZF_PREVIEW_LABEL == '$preview_label' ]]"
  modal() { echo "transform~$in_preview && echo '$2' || echo '$1'~"; }
  local toggle
  toggle=$(modal \
    "change-preview-label($preview_label)+change-preview-window(border-bold)" \
    "change-preview-label($list_label)+change-preview-window(border-rounded)")

  "$self" --list "$dir" |
    fzf --ansi --read0 --no-input --layout reverse \
      --with-shell 'bash -c' \
      --delimiter $'\t' --with-nth '2..' \
      --gap --highlight-line --pointer '▌' \
      --header "$header" \
      --preview "$q_self --render $q_dir {1}" \
      --preview-window 'right,60%,wrap,border-rounded' \
      --preview-label "$list_label" \
      --bind 'load:last' \
      --bind "ctrl-w:$toggle" \
      --bind "tab:$toggle" \
      --bind "j:$(modal down preview-down)" \
      --bind "down:$(modal down preview-down)" \
      --bind "k:$(modal up preview-up)" \
      --bind "up:$(modal up preview-up)" \
      --bind "g:$(modal first preview-top)" \
      --bind "G:$(modal last preview-bottom)" \
      --bind 'J:down,K:up' \
      --bind 'ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up' \
      --bind "enter:execute-silent($q_self --open $q_dir {1})" \
      --bind "r:reload-sync($q_self --refresh $q_dir)" \
      --bind 'q:abort' ||
    :
}

case "${1:-}" in
--list) list "$2" ;;
--render) render "$2" "$3" ;;
--refresh)
  # on failure keep showing the previous data rather than an empty list
  fetch "$2" || true
  list "$2"
  ;;
--open) open_entry "$2" "$3" ;;
-h | --help) usage ;;
*) main "$@" ;;
esac
