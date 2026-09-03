width="${COLUMNS:-$(tput cols 2>/dev/null || echo 100)}"
me="$(gh api user --jq .login 2>/dev/null || true)"

gh pr list --json number,title,author,headRefName,headRepositoryOwner,isCrossRepository,baseRefName,createdAt,updatedAt,url,isDraft,latestReviews,reviewRequests,statusCheckRollup "$@" \
  | jq -r \
    --argjson now "$(date +%s)" \
    --argjson width "$width" \
    --arg me "$me" \
    '
      def spaces($n): if $n > 0 then " " * $n else "" end;

      def pad($n): . + spaces($n - length);

      def truncate($n): if length > $n then (.[:$n - 1] + "…") else . end;

      def ago($n; $unit): "\($n) \($unit)\(if $n == 1 then "" else "s" end) ago";

      def reltime($now):
        ($now - fromdateiso8601) as $d
        | if $d < 60 then "just now"
          elif $d < 3600 then ago($d / 60 | floor; "minute")
          elif $d < 86400 then ago($d / 3600 | floor; "hour")
          elif $d < 604800 then ago($d / 86400 | floor; "day")
          elif $d < 2592000 then ago($d / 604800 | floor; "week")
          elif $d < 31536000 then ago($d / 2592000 | floor; "month")
          else ago($d / 31536000 | floor; "year")
          end;

      def link($url): "\u001b]8;;\($url)\u001b\\" + . + "\u001b]8;;\u001b\\";
      def colour($c): "\u001b[\($c)m" + . + "\u001b[0m";

      def symbol:
        { "APPROVED": "✓",
          "CHANGES_REQUESTED": "✗",
          "COMMENTED": "•",
          "DISMISSED": "⊘",
          "PENDING": "…",
          "REQUESTED": "…"
        }[.] // "?";

      def state_colour:
        { "APPROVED": "32",
          "CHANGES_REQUESTED": "31",
          "COMMENTED": "33",
          "DISMISSED": "90",
          "PENDING": "90",
          "REQUESTED": "90"
        }[.] // "90";

      # bot detection / display cleanup, on a login string
      def bot_login:
        test("^app/")
        or test("\\[bot\\]$")
        or (ascii_downcase | IN("claude", "copilot", "github-actions", "coderabbitai"));

      def clean_login: sub("^app/"; "") | sub("(\\[bot\\]|-bot)$"; "");

      def is_bot: (.bot == true) or (.name | bot_login);

      def reviewers:
        [ (.latestReviews // [])[]
          | { name: .author.login, bot: (.author.is_bot // false), state: .state } ]
        + [ (.reviewRequests // [])[]
            | { name: (.login // .name // .slug // "?"),
                bot: (.__typename == "Bot"),
                state: "REQUESTED" } ]
        | map(select(is_bot | not))
        | map(. + { text: "\(.name)\(.state | symbol)" });

      # aggregate CI state over the checks of the head commit
      def check_state:
        if .__typename == "CheckRun" then
          if .status != "COMPLETED" then "PENDING"
          elif (.conclusion | IN("SUCCESS", "NEUTRAL", "SKIPPED")) then "SUCCESS"
          else "FAILURE"
          end
        else
          if .state == "SUCCESS" then "SUCCESS"
          elif .state == "PENDING" or .state == "EXPECTED" then "PENDING"
          else "FAILURE"
          end
        end;

      # the actions run id a check run belongs to, 0 for anything else
      def run_id:
        ((.detailsUrl // "")
         | capture("/actions/runs/(?<id>[0-9]+)")
         | .id
         | tonumber) // 0;

      # older runs of a workflow stick around in the rollup, keep only the
      # newest run of each workflow so cancelled/superseded jobs are ignored
      def live_checks:
        [ (.statusCheckRollup // [])[] ]
        | ( ( map(select(.__typename == "CheckRun"))
              | group_by(.workflowName)
              | map((map(run_id) | max) as $latest | map(select(run_id == $latest)))
              | add // [] )
            + map(select(.__typename != "CheckRun")) );

      def ci:
        [ live_checks[] | check_state ] as $states
        | if ($states | length) == 0 then "NONE"
          elif ($states | any(. == "FAILURE")) then "FAILURE"
          elif ($states | any(. == "PENDING")) then "PENDING"
          else "SUCCESS"
          end;

      def ci_symbol:
        { "SUCCESS": "✓", "FAILURE": "✗", "PENDING": "•" }[.] // "-";

      def ci_colour:
        { "SUCCESS": "32", "FAILURE": "31", "PENDING": "33" }[.] // "90";

      # stacked PRs are listed above the PR they are based on
      def stack($id; $children; $by_id):
        ( [ ($children[$id] // [])[] | stack(.; $children; $by_id) ] | add // [] )
        + [ $by_id[$id] ];

      [ .[] | {
          id: "#\(.number)",
          url: .url,
          title: .title,
          author: (.author.login // "?" | clean_login),
          author_bot: ((.author.login // "") | bot_login),
          author_me: ($me != "" and (.author.login // "") == $me),
          ci: ci,
          owner: (.headRepositoryOwner.login // ""),
          fork: (.isCrossRepository // false),
          branch: .headRefName,
          # displayed branch, prefixed with the fork owner for cross-repo PRs
          branch_text: (if (.isCrossRepository // false)
                        then "\(.headRepositoryOwner.login // "?"):\(.headRefName)"
                        else .headRefName end),
          # stacks only exist within a single fork, so qualify branch names
          # with the owner of the head repository to avoid linking PRs that
          # happen to share a branch name across forks
          branch_key: "\(.headRepositoryOwner.login // ""):\(.headRefName)",
          base_key: "\(.headRepositoryOwner.login // ""):\(.baseRefName)",
          created: (.createdAt | reltime($now)),
          updated: (.updatedAt | reltime($now)),
          reviewers: reviewers,
          draft: .isDraft
        }
        | . + { reviews: (.reviewers | map(.text) | join(" ")) } ] as $rows
      | if ($rows | length) == 0 then
          "no matching pull requests" | colour("90")
        else
          ($rows | map({ key: .branch_key, value: .id }) | from_entries) as $by_branch
          | ( $rows
              | map($by_branch[.base_key] as $parent
                    | . + { parent: (if $parent == .id then null else $parent end) }) ) as $rows
          | ($rows | map({ key: .id, value: . }) | from_entries) as $by_id
          | ( $rows
              | map(select(.parent != null))
              | group_by(.parent)
              | map({ key: .[0].parent, value: map(.id) })
              | from_entries ) as $children
          | ( [ $rows[] | select(.parent == null) | stack(.id; $children; $by_id) ]
              | add // [] ) as $ordered
          # any parent cycle would drop rows entirely, fall back to flat order
          | (if ($ordered | length) == ($rows | length) then $ordered else $rows end) as $rows
          | ($rows | map(.id | length) + [2] | max) as $idw
          | ($rows | map(.author | length) + [6] | max) as $authorw
          | 2 as $ciw
          | ($rows | map(.branch_text | length) + [6] | max) as $branchw
          | ($rows | map(.reviews | length) + [7] | max) as $revw
          | ($rows | map(.created | length) + [7] | max) as $createdw
          | ($rows | map(.updated | length) + [7] | max) as $updatedw
          | ([$width - $idw - $authorw - $ciw - $branchw - $revw - $createdw - $updatedw - 16, 20] | max) as $maxtitlew
          | ([($rows | map(.title | length) + [5] | max), $maxtitlew] | min) as $titlew
          | ( ("ID" | pad($idw) | colour("1;4"))
              + "  "
              + ( [ ("TITLE" | pad($titlew)),
                    ("AUTHOR" | pad($authorw)),
                    ("CI" | pad($ciw)),
                    ("REVIEWS" | pad($revw)),
                    ("BRANCH" | pad($branchw)),
                    ("CREATED" | pad($createdw)),
                    ("UPDATED" | pad($updatedw))
                  ]
                  | map(colour("1;4"))
                  | join("  ") )
            ),
            ( $rows[] as $row
              | ($row.id | pad($idw) | colour(if $row.draft then "90" else "32" end))
              + (if $row.parent != null then " " + ("⋎" | colour("33")) else "  " end)
              + ( [ ( ($row.title | truncate($titlew)) as $title
                    | ($title | link($row.url)) + spaces($titlew - ($title | length)) ),
                  ( $row.author
                    | pad($authorw)
                    | colour(if $row.author_bot then "90"
                             elif $row.author_me then "1;35"
                             else "35" end) ),
                  (($row.ci | ci_symbol | colour($row.ci | ci_colour))
                   + spaces($ciw - 1)),
                  ( ( $row.reviewers
                      | map(. as $r
                            | $r.text
                            | colour((if $r.name == $me and $me != "" then "1;" else "" end)
                                     + ($r.state | state_colour)))
                      | join(" ") )
                    + spaces($revw - ($row.reviews | length)) ),
                  ( (if $row.fork then ("\($row.owner):" | colour("90")) else "" end)
                    + ($row.branch | colour("36"))
                    + spaces($branchw - ($row.branch_text | length)) ),
                  ($row.created | pad($createdw) | colour("90")),
                  ($row.updated | colour("90"))
                ]
                | join("  ") )
            )
        end
    '
