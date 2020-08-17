#!/bin/zsh

set -eu

shift

metadata="$(cargo metadata --format-version=1 | jq '. as $data | .resolve.root as $root | .packages[] | select(.id == $root) | .metadata.docs.rs')"

val() {
    echo "$metadata" | jq -r "$1"
}

typeset -a args

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
    export RUSTCARGS="${RUSTCARGS-} $(val '.["rustc-args"]')"
fi

if [[ "$(val '.["rustdoc-args"]')" != "null" ]]
then
    export RUSTDOCARGS="${RUSTDOCARGS-} $(val '.["rustdoc-args"] | join(" ")')"
fi

echo cargo doc --no-deps "${args[@]}" "$@"
cargo doc --no-deps "${args[@]}" "$@"
