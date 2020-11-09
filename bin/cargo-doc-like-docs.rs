#!/bin/zsh

set -eu

shift

metadata="$(cargo metadata --format-version=1 | jq '. as $data | .resolve.root as $root | .packages[] | select(.id == $root) | .metadata.docs.rs')"

val() {
    echo "$metadata" | jq -r "$1"
}

args=($@ --locked)
env_args=(DOCS_RS=1)
rustdoc_args=(-Z unstable-options)

if [[ "$(val '.["all-features"]')" = "true" ]]
then
    args+="--all-features"
fi

if [[ "$(val '.["no-default-features"]')" = "true" ]]
then
    args+="--no-default-features"
fi

if [[ "$(val '.features')" != "null" ]]
then
    args+="--features"
    args+="$(val '.features | join(",")')"
fi

if [[ "$(val '.["default-target"]')" != "null" ]]
then
    args+="--target"
    args+="$(val '.["default-target"]')"
fi

if [[ "$(val '.["default-target"]')" = "null" && "$(val '.targets[0]')" != "null" ]]
then
    args+="--target"
    args+="$(val '.targets[0]')"
fi

if [[ "$(val '.["rustc-args"]')" != "null" ]]
then
    env_args+="RUSTCFLAGS=${RUSTCFLAGS-} $(val '.["rustc-args"] | join(" ")')"
fi

val '.["rustdoc-args"] // empty | .[]' | while read -r arg
do
    rustdoc_args+="$arg"
done

metaval() {
    env "${env_args[@]}" cargo metadata --format-version=1 "${args[@]}" | jq -r "$1"
}

metaval '
      . as $data
    | .resolve.root as $root
    | .resolve.nodes[]
    | select(.id == $root)
    | .deps[]
    | . as $dep
    | $data.packages[]
    | select(.id == $dep.pkg)
    | "\(.name | gsub("-"; "_")) \(.name) \(.version)"
  ' \
  | while read -r crate package version
    do
        rustdoc_args+="--extern-html-root-url"
        rustdoc_args+="$crate=https://docs.rs/$package/$version"
    done

echo '     [36;1mRunning[0m `env '"${env_args[@]}"' cargo check '"${args[@]}"' --message-format=json`' >&2
env "${env_args[@]}" cargo check "${args[@]}" --message-format=json \
  | jq -r '
      select(.reason == "compiler-artifact")
    | select(.target.kind[] | contains("lib"))
    | "\(.package_id)\u001F\(.filenames[])"
  ' \
  | while IFS="$(printf '\x1F')" read -r id file
    do
        export id
        rustdoc_args+="--extern-html-root-url"
        rustdoc_args+="$file=$(metaval '.packages[] | select(.id == env.id) | "https://docs.rs/\(.name)/\(.version)"')"
    done

echo '     [36;1mRunning[0m `env '"${env_args[@]}"' cargo rustdoc '"${args[@]}"' -- '"${rustdoc_args[@]}"'`' >&2
env "${env_args[@]}" cargo rustdoc "${args[@]}" -- "${rustdoc_args[@]}"
