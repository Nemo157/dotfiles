{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.md-tui;
  toml = pkgs.formats.toml {};
in {
  options.programs.md-tui = {
    enable = mkEnableOption "md-tui markdown viewer";

    package = mkOption {
      type = types.package;
      default = pkgs.md-tui;
      description = "The md-tui package to use";
    };

    settings = mkOption {
      type = toml.type;
      default = {};
      description = "Configuration written to ~/.config/mdt/config.toml";
      example = literalExpression ''
        {
          down = "j";
          up = "k";
          bold_color = "yellow";
          italic_color = "magenta";
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."mdt/config.toml" = mkIf (cfg.settings != {}) {
      source = toml.generate "md-tui-config.toml" cfg.settings;
    };
  };
}
