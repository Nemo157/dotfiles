{ config, lib, pkgs, ... }:
let
  cfg = config.programs.pi;

  configDir = "${config.xdg.configHome}/pi";
  stateDir = "${config.xdg.stateHome}/pi";

  referenceDirs =
    [ "${cfg.package}/lib/node_modules/pi-monorepo" ]
    ++ (cfg.settings.packages or [ ])
    ++ map builtins.dirOf (cfg.settings.extensions or [ ]);

  refDirsBlock = ''

    Self-reference directories readable outside the working tree:
    ${lib.concatMapStringsSep "\n" (p: "- ${p}") referenceDirs}
  '';

  pi-wrapped = pkgs.symlinkJoin {
    pname = "pi-coding-agent-wrapped";
    inherit (cfg.package) version;
    paths = [ cfg.package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in $out/bin/*; do
        wrapProgram "$bin" \
          --set-default PI_CODING_AGENT_DIR "${configDir}" \
          --set-default PI_SKIP_VERSION_CHECK 1 \
          --set-default PI_OFFLINE 1
      done
    '';
  };

  extensionConfigFiles = lib.mapAttrs'
    (name: settings: {
      name = "pi/extensions/${name}/config.json";
      value = { text = builtins.toJSON settings; };
    })
    cfg.extensionSettings;
in
{
  options.programs.pi = {
    enable = lib.mkEnableOption "pi coding agent";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.pi-coding-agent;
      defaultText = lib.literalExpression "pkgs.pi-coding-agent";
      description = "The pi-coding-agent package to install (unwrapped).";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Written verbatim as pi/settings.json.";
    };

    appendSystem = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Prose written to pi/APPEND_SYSTEM.md. The module automatically
        appends a "Self-reference directories" section listing the bundled
        pi-monorepo, settings.packages, and the parent directories of
        settings.extensions.
      '';
    };

    extensionSettings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = ''
        Per-extension configuration. Each `<name> = <attrs>` entry is
        written to pi/extensions/<name>/config.json as JSON, assuming the
        extension follows the convention of reading its config from that
        path.
      '';
    };

    referenceDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default = referenceDirs;
      defaultText = lib.literalMD ''
        Automatically derived from `package`, `settings.packages`, and
        `settings.extensions`.
      '';
      description = ''
        Store paths that pi may need to read outside the working tree:
        the bundled pi-monorepo, every entry in `settings.packages`, and
        the parent directory of every entry in `settings.extensions`.
        Exposed so downstream configuration (e.g. permission rules) can
        allow-list them.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pi-wrapped ];

    xdg.configFile = {
      "pi/settings.json".text = builtins.toJSON cfg.settings;

      "pi/APPEND_SYSTEM.md".text = cfg.appendSystem + refDirsBlock;

      "pi/auth.json".source =
        config.lib.file.mkOutOfStoreSymlink "${stateDir}/auth.json";
      "pi/sessions".source =
        config.lib.file.mkOutOfStoreSymlink "${stateDir}/sessions";
    } // extensionConfigFiles;

    # Ensure the state dir exists before pi first tries to write auth.json
    # / sessions into it.
    home.activation.piStateDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${lib.escapeShellArg "${stateDir}/sessions"}
    '';
  };
}
