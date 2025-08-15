{ config, lib, pkgs, ... }:
let
  unwrapped = pkgs.unstable.claude-code;

  json = pkgs.formats.json {};

  allowed-commands = [
    "cargo check"
    "cargo clippy"
    "cargo test"
    "jj diff"
    "jj file show"
    "jj log"
    "jj new"
    "jj show"
    "jj status"
    "rg"
  ];

  allowed-mcp = {
    linear-server = [
      "get_document"
      "get_issue"
      "get_issue_status"
      "get_project"
      "get_team"
      "get_user"
      "list_comments"
      "list_cycles"
      "list_documents"
      "list_issue_labels"
      "list_issue_statuses"
      "list_issues"
      "list_my_issues"
      "list_project_labels"
      "list_projects"
      "list_teams"
      "list_users"
      "search_documentation"
    ];
  };

  claude-code-settings = json.generate "claude-code-settings.json" {
    includeCoAuthoredBy = false;
    permissions = {
      allow = 
        (map (command: "Bash(${command}:*)") allowed-commands) ++
        (lib.flatten (lib.mapAttrsToList (server: functions: 
          map (func: "mcp__${server}__${func}") functions
        ) allowed-mcp));
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
  xdg.configFile."claude/imports".source = ./imports;
  xdg.configFile."claude/agents".source = ./agents;

  xdg.configFile."claude/settings.json".source = claude-code-settings;

  # Run a claude instance in a fresh workspace
  scripts.jj-claude = {
    runtimeInputs = [ pkgs.coreutils pkgs.jujutsu claude-code ];
    source = ./jj-claude.sh;
  };

  programs.jujutsu.settings.aliases.claude = ["util" "exec" "--" "jj-claude"];
}
