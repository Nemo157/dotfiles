{ config, lib, pkgs, ... }:

let
  cfg = config.programs.linear-cli;

  linearWrapper = pkgs.writeShellApplication {
    name = "linear";
    text = ''
      ${lib.optionalString (cfg.environmentFile != null) ''
        if [ -f "${cfg.environmentFile}" ]; then
          # shellcheck disable=SC1090,SC1091
          source "${cfg.environmentFile}"
        fi
      ''}
      exec ${lib.getExe cfg.package} "$@"
    '';
  };
in
{
  options.programs.linear-cli = {
    enable = lib.mkEnableOption "Linear CLI";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.linear-cli;
      description = "The linear-cli package to use";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing environment variables to source before running linear.
        Useful for loading LINEAR_API_KEY from agenix or similar secret management tools.
      '';
      example = "/run/agenix/linear-api-key";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (if cfg.environmentFile != null then linearWrapper else cfg.package)
    ];
  };
}
