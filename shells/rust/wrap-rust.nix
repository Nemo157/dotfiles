{ pkgs, ... }: rust-toolchain:
let
  rustc-wrapped = pkgs.writeShellApplication {
    name = "rustc";
    runtimeInputs = [ pkgs.gnused ];
    text = ''
      is_version() {
        while [ $# -gt 0 ]
        do
          case "$1" in
            -V | --version)
              return 0
              ;;
          esac
          shift
        done
        return 1
      }

      if is_version "$@"
      then
        ${rust-toolchain}/bin/rustc "$@" | sed 's/-nightly//g'
      else
        exec ${rust-toolchain}/bin/rustc "$@"
      fi
    '';
  };
in pkgs.symlinkJoin {
  inherit (rust-toolchain) name;
  paths = [
    rustc-wrapped
    rust-toolchain
  ];
}
