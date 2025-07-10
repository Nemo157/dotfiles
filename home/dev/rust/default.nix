{ lib, pkgs, ... }: {
  imports = [
    ./bacon.nix
    ./cargo.nix
  ];

  home.packages = [
    pkgs.cargo-rubber
  ];

  home.sessionVariables = {
    RUST_BACKTRACE = "1";
    # Directory that rustc dumps internal compiler error files to
    RUSTC_ICE = "/tmp";
  };

  # scripts.for-each-rust = {
  #   text = let
  #     rusts = lib.filterAttrs (v: c: (lib.hasPrefix "1." v)) pkgs.rust-bin.stable;
  #     scripts = lib.mapAttrsToList (v: c: ''
  #       printf "\e[1m==== %s ====\e[0m\n" "${v}"
  #       echo
  #       PATH="${if c ? "minimal" then c.minimal else c.rust}/bin:$PATH" "$@" || true
  #       echo
  #       echo
  #     '') rusts;
  #   in builtins.concatStringsSep "\n" scripts;
  # };
}
