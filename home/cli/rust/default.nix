{ pkgs, ... }: {
  home.packages = with pkgs; [
    bacon
    cargo-deny
    cargo-dl
    cargo-expand
    cargo-fuzz
    cargo-hack
    cargo-nextest
    cargo-supply-chain
    cargo-sweep
    cargo-udeps
    cargo-vet
    cargo-watch
    (rust-bin.selectLatestNightlyWith (toolchain: toolchain.default))
  ];

  home.file.".local/bin/cargo-rubber".source = ./cargo-rubber;
  home.file.".local/bin/cargo-rustdoc-clippy".source = ./cargo-rustdoc-clippy;
  home.file.".local/bin/cargo-doc-like-docs.rs".source = ./cargo-doc-like-docs.rs;
}
