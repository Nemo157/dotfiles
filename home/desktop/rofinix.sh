run() {
  local cmd="$1"
  shift
  printf '\e[34m$ %q' "$cmd" >&2
  printf ' %q' "$@" >&2
  printf '\e[0m\n' >&2
  "$cmd" "$@"
}

cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/rofinix.cache"

if [ "$ROFI_RETV" = 0 ]
then
  if [ -f "$cache_file" ]
  then
    while read -r count app
    do
      echo "$app"
    done <"$cache_file"
  fi
else
  # shellcheck disable=SC2206
  cmd=($1)

  declare -A cache=()

  if [ -f "$cache_file" ]
  then
    while read -r count app
    do
      cache["$app"]=$count
    done <"$cache_file"
  fi

  (( cache["$1"] += 1 ))

  for app in "${!cache[@]}"
  do
    echo "${cache[$app]} $app"
  done | sort -nr >"$cache_file"

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
              --command
                bash -c '"'"'
                  nix build --no-link --verbose "pkgs#$1" || sleep 60
                '"'"' -- "$pkg"
          )
          alacritty "${args[@]}"

          # alacritty doesnt return an exit code based on command completion,
          # instead check whether the package now exists in the store (this is
          # fast unless the `nix build` was canceled _very_ early).
          if nix path-info "pkgs#$pkg"
          then
            exec nix run "pkgs#$pkg" -- "$@"
          fi
        ' -- "$pkg" "${cmd[@]}"
  )
  run exec "${systemd_run[@]}"
fi
