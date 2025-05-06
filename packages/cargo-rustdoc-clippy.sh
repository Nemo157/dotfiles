if [[ $# -gt 0 && "$1" = "rustdoc-clippy" ]]
then
  shift
fi

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

while [[ $# -gt 0 ]]
do
  rustdoc_args+="--doctest-compilation-args=$1"
  shift
done

RUSTDOCFLAGS="--no-run --nocapture --test-builder clippy-driver -Z unstable-options ${rustdoc_args[@]}" exec cargo test --doc "${cargo_args[@]}"
