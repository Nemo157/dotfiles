set -euo pipefail

input="$(cat)"

model=$(jq -r '.model.display_name' <<<"$input")
cost=$(jq -r '.cost.total_cost_usd * 100 | round / 100' <<<"$input")

duration=$(jq -r '
  (.cost.total_duration_ms / 1000) as $seconds |
  if $seconds >= 3600 then
    "\($seconds / 3600 | floor)h\(($seconds % 3600) / 60 | floor)m"
  elif $seconds >= 60 then
    "\($seconds / 60 | floor)m\($seconds % 60 | floor)s"
  else
    "\($seconds | floor)s"
  end
' <<<"$input")

added=$(jq -r '.cost.total_lines_added' <<<"$input")
removed=$(jq -r '.cost.total_lines_removed' <<<"$input")

project=$(jq -r '.workspace.project_dir' <<<"$input")
current=$(jq -r '.workspace as $workspace | $workspace.current_dir | ltrimstr($workspace.project_dir)' <<<"$input")

printf '\e[37m\uEE0D %s\e[0m | \e[33m$%s\e[0m | \e[34m\uF017 %s\e[0m | \e[32m+%s\e[31m-%s\e[0m in \e[2;36m%s\e[1;36m%s\e[0m\n' \
  "$model" "$cost" "$duration" "$added" "$removed" "$project" "$current"
if jj root --ignore-working-copy >/dev/null
then
  jj lo --ignore-working-copy --color=always --limit 4
fi
