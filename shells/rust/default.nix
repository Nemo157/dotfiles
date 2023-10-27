{ pkgs, lib, ... }:
let
  rust-wrapped = pkgs.callPackage ./rust-wrapped.nix {};
  setup-xdg-cargo-home = pkgs.writeShellApplication {
    name = "setup-xdg-cargo-home";
    text = lib.readFile ./setup-xdg-cargo-home;
  };
in pkgs.mkShell {
  buildInputs = with pkgs; [
    bacon
    cargo-deny
    cargo-dl
    cargo-doc-like-docs-rs
    cargo-expand
    cargo-fuzz
    cargo-hack
    cargo-minimal-versions
    cargo-nextest
    cargo-rubber
    cargo-supply-chain
    cargo-sweep
    cargo-udeps
    cargo-vet
    cargo-watch
    rust-wrapped
  ];

  shellHook = ''
    ${lib.getExe setup-xdg-cargo-home}
  '';
}
