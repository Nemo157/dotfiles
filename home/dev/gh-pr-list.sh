width="${COLUMNS:-$(tput cols 2>/dev/null || echo 100)}"
me="$(gh api user --jq .login 2>/dev/null || true)"

gh pr list --json number,title,author,headRefName,baseRefName,createdAt,updatedAt,url,isDraft,latestReviews,reviewRequests "$@" \
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
          branch: .headRefName,
          base: .baseRefName,
          created: (.createdAt | reltime($now)),
          updated: (.updatedAt | reltime($now)),
          reviewers: reviewers,
          draft: .isDraft
        }
        | . + { reviews: (.reviewers | map(.text) | join(" ")) } ] as $rows
      | if ($rows | length) == 0 then
          "no matching pull requests" | colour("90")
        else
          ($rows | map({ key: .branch, value: .id }) | from_entries) as $by_branch
          | ($rows | map(. + { parent: $by_branch[.base] })) as $rows
          | ($rows | map({ key: .id, value: . }) | from_entries) as $by_id
          | ( $rows
              | map(select(.parent != null))
              | group_by(.parent)
              | map({ key: .[0].parent, value: map(.id) })
              | from_entries ) as $children
          | ( [ $rows[] | select(.parent == null) | stack(.id; $children; $by_id) ]
              | add // [] ) as $rows
          | ($rows | map(.id | length) + [2] | max) as $idw
          | ($rows | map(.author | length) + [6] | max) as $authorw
          | ($rows | map(.branch | length) + [6] | max) as $branchw
          | ($rows | map(.reviews | length) + [7] | max) as $revw
          | ($rows | map(.created | length) + [7] | max) as $createdw
          | ($rows | map(.updated | length) + [7] | max) as $updatedw
          | ([$width - $idw - $authorw - $branchw - $revw - $createdw - $updatedw - 14, 20] | max) as $maxtitlew
          | ([($rows | map(.title | length) + [5] | max), $maxtitlew] | min) as $titlew
          | ( ("ID" | pad($idw) | colour("1;4"))
              + "  "
              + ( [ ("TITLE" | pad($titlew)),
                    ("AUTHOR" | pad($authorw)),
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
                  ( ( $row.reviewers
                      | map(. as $r
                            | $r.text
                            | colour((if $r.name == $me and $me != "" then "1;" else "" end)
                                     + ($r.state | state_colour)))
                      | join(" ") )
                    + spaces($revw - ($row.reviews | length)) ),
                  ($row.branch | pad($branchw) | colour("36")),
                  ($row.created | pad($createdw) | colour("90")),
                  ($row.updated | colour("90"))
                ]
                | join("  ") )
            )
        end
    '
