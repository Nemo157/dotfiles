run() {
  local cmd="$1"
  shift
  printf '\e[34m$ %q' "$cmd" >&2
  printf ' %q' "$@" >&2
  printf '\e[0m\n' >&2
  "$cmd" "$@"
}

cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/rofinix.cache"

list_cache() {
  if [ -f "$cache_file" ]
  then
    while read -r _count app
    do
      echo "$app"
    done <"$cache_file"
  fi
}

declare -A cache=()

load_cache() {
  if [ -f "$cache_file" ]
  then
    while read -r count app
    do
      cache["$app"]=$count
    done <"$cache_file"
  fi
}

save_cache() {
  for app in "${!cache[@]}"
  do
    echo "${cache[$app]} $app"
  done | sort -nr >"$cache_file"
}

if [ "$ROFI_RETV" = 0 ]
then
  list_cache
elif [ "$ROFI_RETV" = 3 ]
then
  # kb-delete-entry: drop the entry and redisplay the list
  load_cache
  unset 'cache[$1]'
  save_cache
  list_cache
elif [ "$ROFI_RETV" = 1 ] || [ "$ROFI_RETV" = 2 ]
then
  # 1: selected an entry, 2: selected a custom (typed) entry
  # shellcheck disable=SC2206
  cmd=($1)

  load_cache
  (( cache["$1"] += 1 ))
  save_cache

  pkg="${cmd[0]}"
  unset "cmd[0]"

  app="$(systemd-escape "$pkg")"
  unit="app-rofinix-$app-$RANDOM"

  # shellcheck disable=SC2016
  systemd_run=(
    systemd-run
      --scope
      --user
      --slice-inherit
      --slice="$app"
      --unit="$unit"
      --expand-environment=false
      systemd-cat
        --identifier="$app"
        bash -c '
          set -euo pipefail
          pkg="$1"
          shift

          # show download status if we dont have it
          args=(
              --class rofinix-build
              --title "nix build pkgs#$pkg"
              bash -c '"'"'
                nix build --no-link --verbose "pkgs#$1" || sleep 60
              '"'"' -- "$pkg"
          )
          kitty "${args[@]}"

          if nix path-info "pkgs#$pkg"
          then
            exec nix run "pkgs#$pkg" -- "$@"
          fi
        ' -- "$pkg" "${cmd[@]}"
  )
  run exec "${systemd_run[@]}"
else
  # unhandled (e.g. custom keybindings 10-28): ignore
  exit 0
fi
