if [ "$1" = "rubber" ]
then
  shift
fi

args=(--frozen --offline "$@")

manifest=()
case "${1:-}" in
  --manifest-path=*)
    manifest+=("$1")
    shift
    ;;
  --manifest-path)
    manifest+=("--manifest-path=$2")
    shift
    shift
    ;;
esac

printf '    \e[36;1mFetching\e[0m dependencies\n' >&2
cargo fetch "${manifest[@]}"

root="$(cargo metadata "${manifest[@]}" --format-version 1 | jq -r .workspace_root)"
target_dir="$(realpath "$(cargo metadata "${manifest[@]}" --format-version 1 | jq -r .target_directory)")"
mkdir -p "$target_dir"

bwrap_args=(
  --ro-bind / /
  --dev /dev
  --tmpfs /tmp
  --ro-bind "$root" "$root"
  --ro-bind "${CARGO_HOME:-$HOME/.cargo}" "${CARGO_HOME:-$HOME/.cargo}"
  --bind "$target_dir" "$target_dir"
  --unshare-net
  --unsetenv TMPDIR
)

printf '     \e[36;1mRunning\e[0m `bwrap' >&2
printf ' %q' "${bwrap_args[@]}" cargo "${args[@]}" >&2
printf '`\n' >&2

bwrap "${bwrap_args[@]}" cargo "${args[@]}"
