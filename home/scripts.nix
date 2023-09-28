{ lib, config, pkgs, ... }:
let
  inherit (lib) mkOption mapAttrs' nameValuePair types getExe;
  inherit (pkgs) writeShellApplication;
  binHome = "${config.home.homeDirectory}/.local/bin";
in {
  options = {
    scripts = mkOption {
      type = types.attrsOf(types.submodule {
        options = {
          text = mkOption {
            type = types.lines;
          };
          runtimeInputs = mkOption {
            type = types.listOf types.package;
          };
        };
      });
    };
  };

  config = {
    home.sessionPath = [ binHome ];

    home.file = mapAttrs'
    (name: file:
      let
        source = getExe (writeShellApplication {
          inherit name;
          inherit (file) runtimeInputs text;
        });
      in nameValuePair "${binHome}/${name}" { inherit source; }
    )
      config.scripts;
  };
}
