if [ "$#" -gt 0 ] && [ "${1:0:1}" = "+" ]
then
  channel="${1:1}"
  shift
else
  channel="nightly"
fi

command="$(basename "$0")"

expr='
  { channel }:
  let
    system = builtins.currentSystem;
    nixpkgs = builtins.getFlake "nixpkgs";
    rust-overlay = builtins.getFlake "github:oxalica/rust-overlay";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        rust-overlay.overlays.default
      ];
    };
  in
    pkgs.rust-bin.fromRustupToolchain { inherit channel; }
'

exec nix shell \
  --override-flake github:NixOS/nixpkgs/nixpkgs-unstable nixpkgs \
  --impure \
  --expr "$expr" \
  --argstr channel "$channel" \
  --command "$command" "$@"
