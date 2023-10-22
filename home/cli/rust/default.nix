{ config, pkgs, ... }: {
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

  programs.zsh.profileExtra = ''
    export CARGO_HOME="$XDG_RUNTIME_DIR/cargo"

    if ! [ -e "$CARGO_HOME" ]
    then
      (
        _link_cargo_dir() {
          base="$1"
          shift
          while [[ $# -gt 0 ]]; do
            mkdir -p "$CARGO_HOME/$(dirname "$1")" "$base/cargo/$(dirname "$1-")"
            ln -st "$CARGO_HOME/$(dirname "$1")" "$base/cargo/$1"
            shift
          done
        }

        _link_cargo_dir "${config.xdg.configHome}" config.toml
        _link_cargo_dir "${config.xdg.dataHome}" credentials.toml
        _link_cargo_dir "${config.xdg.stateHome}" git/db/ registry/index/ registry/cache/
        _link_cargo_dir "${config.xdg.cacheHome}" git/checkouts/ registry/src/

        chmod -R a-w $CARGO_HOME
      )
    fi
  '';
}
