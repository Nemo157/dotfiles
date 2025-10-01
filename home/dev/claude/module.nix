{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.claude-code;

  unwrapped = pkgs.unstable.claude-code;
  json = pkgs.formats.json {};

  permissionsType = types.submodule {
    freeformType = json.type;
    options = {
      allow = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of allowed capabilities/commands";
        example = [ "WebSearch" "Bash(cargo check:*)" "mcp__linear-server__get_issue" ];
      };

      deny = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of denied capabilities/commands";
      };

      defaultMode = mkOption {
        type = types.enum [ "acceptEdits" "ask" "deny" ];
        description = "Default permission mode for Claude operations";
      };
    };
  };

  statusLineType = types.submodule {
    freeformType = json.type;
    options = {
      type = mkOption {
        type = types.enum [ "command" ];
        description = "Type of status line";
      };

      command = mkOption {
        type = types.str;
        description = "Command to execute for status line";
      };
    };
  };

  settingsType = types.submodule {
    freeformType = json.type;
    options = {
      includeCoAuthoredBy = mkOption {
        type = types.bool;
        description = "Whether to include co-authored-by in commit messages";
      };

      permissions = mkOption {
        type = permissionsType;
        description = "Permission configuration for Claude Code";
      };

      env = mkOption {
        type = types.attrsOf types.str;
        description = "Environment variables for Claude sessions";
      };

      statusLine = mkOption {
        type = types.nullOr statusLineType;
        description = "Status line configuration";
        example = {
          type = "command";
          command = "/path/to/statusline-script";
        };
      };
    };
  };

  claude-code-settings = json.generate "claude-code-settings.json" cfg.settings;

  importFiles = lib.mapAttrs (name: import:
    if import.text != null then
      pkgs.writeText "${name}.md" import.text
    else if import.source != null then
      import.source
    else
      throw "Import '${name}' must have either text or source specified"
  ) cfg.imports;

  importReferences = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: import:
    "Reference @${importFiles.${name}} for ${import.description}"
  ) cfg.imports);

  claudeMdContent = if cfg.imports != {} then
    cfg.memory + "\n" + importReferences
  else
    cfg.memory;

  claude-md-file = pkgs.writeText "CLAUDE.md" claudeMdContent;

  agentFiles = lib.mapAttrs (name: agent:
    if agent.text != null then
      pkgs.writeText "${name}.md" agent.text
    else if agent.source != null then
      agent.source
    else
      throw "Agent '${name}' must have either text or source specified"
  ) cfg.agents;

  claude-code = pkgs.runCommand unwrapped.name {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } ''
    makeWrapper "${lib.getExe unwrapped}" $out/bin/claude \
      --set CLAUDE_CONFIG_DIR ${config.xdg.configHome}/claude
  '';
in {
  options.programs.claude-code = {
    enable = mkEnableOption "Claude Code CLI tool";

    settings = mkOption {
      type = settingsType;
      description = "Claude Code settings to be written to settings.json";
      example = {
        includeCoAuthoredBy = true;
        statusLine = {
          type = "command";
          command = "/path/to/statusline-script";
        };
        permissions = {
          allow = [ "WebSearch" "Bash(cargo check:*)" ];
          defaultMode = "ask";
        };
        env = {
          "CUSTOM_VAR" = "value";
        };
      };
    };

    memory = mkOption {
      type = types.lines;
      description = "Content for CLAUDE.md file";
      example = ''
        # Custom Instructions
        - Use specific coding patterns
        - Follow project conventions
      '';
    };

    agents = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          text = mkOption {
            type = types.nullOr types.lines;
            default = null;
            description = "Agent content as text";
          };

          source = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Agent content from file";
          };
        };
      });
      default = {};
      description = "Agent definitions with name as key and text or source content";
      example = {
        code-reviewer = {
          text = ''
            # Code Reviewer Agent
            Review code for best practices.
          '';
        };
        custom-agent = {
          source = ./agents/custom.md;
        };
      };
    };

    imports = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          text = mkOption {
            type = types.nullOr types.lines;
            default = null;
            description = "Import content as text";
          };

          source = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Import content from file";
          };

          description = mkOption {
            type = types.str;
            description = "Description of what this import provides";
          };
        };
      });
      default = {};
      description = "Import definitions with name as key, content, and description";
      example = {
        jj = {
          source = ./imports/jj.md;
          description = "command mappings and workflow patterns";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ claude-code ];

    xdg.configFile = {
      "claude/settings.json".source = claude-code-settings;
      "claude/CLAUDE.md".source = claude-md-file;
    }
    // (lib.mapAttrs' (name: file: {
      name = "claude/agents/${name}.md";
      value.source = file;
    }) agentFiles);

    programs.git.ignores = [
      ".claude/settings.local.json"
    ];
  };
}
