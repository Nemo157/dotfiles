#!/usr/bin/env zsh

set -eu

if [[ $# -gt 0 && "$1" = "rustdoc-clippy" ]]
then
  shift

  if [[ $# -gt 0 && "$1" = "--help" ]]
  then
    echo "USAGE: cargo rustdoc-clippy [cargo-options] [-- [rustdoc-options] [-- [clippy-options]]]"
    exit
  fi

  cargo_args=()
  while [[ $# -gt 0 && "$1" != "--" ]]
  do
    cargo_args+="$1"
    shift
  done

  if [[ $# -gt 0 ]]
  then
    shift
  fi

  rustdoc_args=()
  while [[ $# -gt 0 && "$1" != "--" ]]
  do
    rustdoc_args+="$1"
    shift
  done

  if [[ $# -gt 0 ]]
  then
    shift
  fi

  clippy_args=()
  while [[ $# -gt 0 ]]
  do
    clippy_args+="$1"
    shift
  done

  CLIPPYFLAGS="${(j:\x1E:)clippy_args}" RUSTDOCFLAGS="--no-run --nocapture --test-builder "$0" -Z unstable-options $rustdoc_args[@]" exec cargo test --doc "$cargo_args[@]"
else
  if [[ "$CLIPPYFLAGS" != "" ]]
  then
    exec clippy-driver "${(@s:\x1E:)CLIPPYFLAGS}" "$@"
  else
    exec clippy-driver "$@"
  fi
fi
