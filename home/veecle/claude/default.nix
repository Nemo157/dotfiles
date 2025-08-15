{ config, lib, pkgs, ... }:
let
  unwrapped = pkgs.unstable.claude-code;

  json = pkgs.formats.json {};

  allowed-commands = ''
    cargo check
    cargo clippy
    cargo test
    jj diff
    jj file show
    jj log
    jj new
    jj show
    jj status
    rg
  '';

  claude-code-settings = json.generate "claude-code-settings.json" {
    includeCoAuthoredBy = false;
    permissions = {
      allow = map (command: "Bash(${command}:*)") (lib.splitString "\n" (lib.removeSuffix "\n" allowed-commands));
      deny = [];
      defaultMode = "acceptEdits";
      env = {
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" = "1";
        "DISABLE_AUTOUPDATER" = "1";
        "DISABLE_BUG_COMMAND" = "1";
        "DISABLE_ERROR_REPORTING" = "1";
        "DISABLE_TELEMETRY" = "1";
      };
    };
  };

  claude-code = pkgs.runCommand unwrapped.name {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } ''
    makeWrapper "${lib.getExe unwrapped}" $out/bin/claude \
      --set CLAUDE_CONFIG_DIR ${config.xdg.configHome}/claude \
      --set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1 \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_BUG_COMMAND 1 \
      --set DISABLE_ERROR_REPORTING 1 \
      --set DISABLE_TELEMETRY 1
  '';
in {
  home.packages = [ claude-code ];

  xdg.configFile."claude/CLAUDE.md".source = ./CLAUDE.md;
  xdg.configFile."claude/jj.md".source = ./jj.md;
  xdg.configFile."claude/agents/code-reviewer.md".source = ./agents/code-reviewer.md;
  xdg.configFile."claude/agents/technical-docs-reviewer.md".source = ./agents/technical-docs-reviewer.md;
  xdg.configFile."claude/agents/config-manager.md".source = ./agents/config-manager.md;

  xdg.configFile."claude/settings.json".source = claude-code-settings;

  # Run a claude instance in a fresh workspace
  scripts.jj-claude = {
    runtimeInputs = [ pkgs.coreutils pkgs.jujutsu claude-code ];
    source = ./jj-claude.sh;
  };

  programs.jujutsu.settings.aliases.claude = ["util" "exec" "--" "jj-claude"];
}
