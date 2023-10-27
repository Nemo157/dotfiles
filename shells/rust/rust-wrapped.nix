{ pkgs, ... }:
let
  rust = pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default);
  rustc-wrapped = pkgs.writeShellApplication {
    name = "rustc";
    runtimeInputs = [ pkgs.gnused ];
    text = ''
      is_version() {
        while [ $# -gt 1 ]
        do
          case "$1" in
            -V | --version)
              return 0
              ;;
          esac
          shift
        done
      }

      if is_version "$@"
      then
        ${rust}/bin/rustc "$@" | sed 's/-nightly//g'
      else
        exec ${rust}/bin/rustc "$@"
      fi
    '';
  };
in pkgs.symlinkJoin {
  inherit (rust) name;
  paths = [
    rustc-wrapped
    rust
  ];
}
