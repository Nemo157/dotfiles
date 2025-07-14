set -euo pipefail

run() {
  printf '\e[34m$' >&2
  printf ' %q' "$@" >&2
  printf '\e[0m\n' >&2
  "$@"
}

dir="$(run mktemp --tmpdir -u -d "jj-claude.$(date +%Y-%m-%dT%H-%M).XXXXXX")"
root="$(run jj root)"
relative="$(run realpath --relative-to "$root" "$PWD")"

cleanup() {
  run cd "$dir"
  run jj workspace forget
  run rm -r "$dir"
}

trap cleanup EXIT
run jj workspace add "$dir"
run cd "$dir/$relative"
run claude "$@"
