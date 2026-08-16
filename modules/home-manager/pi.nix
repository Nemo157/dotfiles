{ config, lib, pkgs, ... }:
let
  cfg = config.programs.pi;

  configDir = "${config.xdg.configHome}/pi";
  stateDir = "${config.xdg.stateHome}/pi";

  referenceDirs =
    [ "${cfg.package}/lib/node_modules/pi-monorepo" ]
    ++ (cfg.settings.packages or [ ])
    ++ map builtins.dirOf (cfg.settings.extensions or [ ]);

  # Stable, versionless symlinks into the store so the injected context can
  # reference short paths (e.g. ~/.config/pi/reference/pi-mcp-adapter) instead
  # of hashed, version-suffixed store paths that are easy to mistranscribe.
  # Keyed by the leaf directory name; collisions would silently drop an entry,
  # so assert the names stay unique.
  referenceLinkNames = map (dir: baseNameOf (builtins.unsafeDiscardStringContext dir)) referenceDirs;
  referenceLinks = lib.listToAttrs
    (lib.zipListsWith lib.nameValuePair referenceLinkNames referenceDirs);
  referenceLinksUnique =
    assert lib.assertMsg
      (lib.length (lib.unique referenceLinkNames) == lib.length referenceDirs)
      "programs.pi reference symlinks have colliding leaf names: ${lib.concatStringsSep ", " referenceLinkNames}";
    referenceLinks;

  refDirsBlock = ''

    Self-reference directories readable outside the working tree:
    ${lib.concatMapStringsSep "\n"
      (name: "- ${configDir}/reference/${name}")
      (lib.attrNames referenceLinksUnique)}
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
          --set-default PI_OFFLINE 1 ${
            lib.optionalString (cfg.extraArgs != [ ])
              "--add-flags ${lib.escapeShellArg (lib.concatStringsSep " " cfg.extraArgs)}"
          }
      done
    '';
  };

  json = pkgs.formats.json {};

  extensionConfigFiles = lib.mapAttrs'
    (name: settings: {
      name = "pi/extensions/${name}/config.json";
      value = { source = json.generate "pi-config.json" settings; };
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
      type = lib.types.attrsOf json.type;
      default = { };
      description = "Written verbatim as pi/settings.json.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--exclude-tools" "bash" ];
      description = ''
        Extra CLI flags baked into the wrapper, for settings pi only
        accepts on the command line (`settings.json` has no equivalent).
        Prepended to the user's arguments, so positional subcommands (only
        `pi update` is matched positionally) are shadowed.
      '';
    };

    appendSystem = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Prose written to pi/APPEND_SYSTEM.md. The module automatically
        appends a "Self-reference directories" section. To keep the injected
        context free of hashed, version-suffixed store paths, it lists stable
        symlinks under pi/reference/<leaf-name> (created from the bundled
        pi-monorepo, settings.packages, and the parent directories of
        settings.extensions) rather than the raw store paths.
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

    referenceLinkDir = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${configDir}/reference";
      description = ''
        Directory of stable, versionless symlinks into the store that the
        injected context points at instead of raw store paths. Exposed so
        permission rules can allow-list it: the permission layer matches on
        the lexical (non-symlink-resolved) path, so this directory must be
        allowed in addition to `referenceDirs`.
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
    } // (lib.mapAttrs'
      (name: path: lib.nameValuePair "pi/reference/${name}" { source = path; })
      referenceLinksUnique) // {

      "pi/auth.json".source =
        config.lib.file.mkOutOfStoreSymlink "${stateDir}/auth.json";
      "pi/models-store.json".source =
        config.lib.file.mkOutOfStoreSymlink "${stateDir}/models-store.json";
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
