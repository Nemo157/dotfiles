width="${COLUMNS:-$(tput cols 2>/dev/null || echo 100)}"

gh pr list --json number,title,headRefName,createdAt,url,isDraft "$@" \
  | jq -r \
    --argjson now "$(date +%s)" \
    --argjson width "$width" \
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

      [ .[] | {
          id: "#\(.number)",
          url: .url,
          title: .title,
          branch: .headRefName,
          age: (.createdAt | reltime($now)),
          draft: .isDraft
        } ] as $rows
      | if ($rows | length) == 0 then
          "no matching pull requests" | colour("2")
        else
          ($rows | map(.id | length) + [2] | max) as $idw
          | ($rows | map(.branch | length) + [6] | max) as $branchw
          | ($rows | map(.age | length) + [7] | max) as $agew
          | ([$width - $idw - $branchw - $agew - 6, 20] | max) as $maxtitlew
          | ([($rows | map(.title | length) + [5] | max), $maxtitlew] | min) as $titlew
          | ( [ ("ID" | pad($idw)),
                ("TITLE" | pad($titlew)),
                ("BRANCH" | pad($branchw)),
                ("CREATED" | pad($agew))
              ]
              | map(colour("1;4"))
              | join("  ")
            ),
            ( $rows[] as $row
              | [ ($row.id | colour(if $row.draft then "90" else "32" end) | link($row.url))
                    + spaces($idw - ($row.id | length)),
                  ($row.title | truncate($titlew) | pad($titlew)),
                  ($row.branch | pad($branchw) | colour("36")),
                  ($row.age | colour("2"))
                ]
              | join("  ")
            )
        end
    '
