if [ "$#" -gt 0 ] && [ "${1:0:1}" = "+" ]
then
  channel="${1:1}"
  command="$(basename "$0")"
  shift
  # shellcheck disable=SC2016
  exec nix shell --impure --expr '((builtins.getFlake "pkgs").legacyPackages.${builtins.currentSystem}.rust-bin.fromRustupToolchain { channel = "'"$channel"'"; })' --command "$command" "$@"
else
  echo missing channel >&2
  exit 1
fi
