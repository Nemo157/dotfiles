{ lib, config, pkgs, ... }:
let
  inherit (lib) mkOption mapAttrs' nameValuePair types getExe;
  inherit (pkgs) writeShellApplication;
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

    binHome = mkOption {
      type = types.path;
      default = "${config.home.homeDirectory}/.local/bin";
      readOnly = true;
    };
  };

  config = {
    home.sessionPath = [ config.binHome ];

    home.file = mapAttrs'
    (name: file:
      let
        source = getExe (writeShellApplication {
          inherit name;
          inherit (file) runtimeInputs text;
        });
      in nameValuePair "${config.binHome}/${name}" { inherit source; }
    )
      config.scripts;
  };
}
