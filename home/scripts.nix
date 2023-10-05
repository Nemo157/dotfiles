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
            type = types.nullOr types.lines;
            default = null;
          };
          source = mkOption {
            type = types.path;
          };
          runtimeInputs = mkOption {
            type = types.listOf types.package;
            default = [];
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
        text = if file.text != null then file.text else lib.readFile file.source;
        source = getExe (writeShellApplication {
          inherit name text;
          inherit (file) runtimeInputs;
        });
      in nameValuePair "${config.binHome}/${name}" { inherit source; }
    )
      config.scripts;
  };
}
