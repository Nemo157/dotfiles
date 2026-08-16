{ lib, config, pkgs, ... }:
let
  cfg = config.programs.niri;
  configFile = pkgs.writeTextFile {
    name = "niri-config.kdl";

    checkPhase = ''
      ${lib.getExe cfg.package} validate --config "$target"
    '';

    text = cfg.config + lib.optionalString (cfg.layout != "") ''

      layout {
      ${cfg.layout}
      }
    '';
  };
in {
  options.programs.niri = {
    enable = lib.mkEnableOption "niri, a scrollable-tiling Wayland compositor";

    package = lib.mkPackageOption pkgs "niri" { };

    config = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Contents of niri's config.kdl. Fragments from multiple modules are
        concatenated, so hosts can append their own blocks (e.g. outputs).
      '';
    };

    layout = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Contents of the single `layout { }` block in niri's config.kdl.
        Kept separate from `config` because niri does not allow duplicate
        layout blocks, so hosts can only extend it from within.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."niri/config.kdl".source = configFile;
  };
}
