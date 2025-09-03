{ config, lib, pkgs, ... }:
let
  unwrapped = pkgs.unstable.claude-code;

  json = pkgs.formats.json {};
  toml = pkgs.formats.toml {};

  allowed-commands = [
    "cargo check"
    "cargo clippy"
    "cargo test"
    "gh browse"
    "gh issue list"
    "gh issue view"
    "gh pr diff"
    "gh pr list"
    "gh pr view"
    "gh repo view"
    "gh status"
    "jj bookmark list"
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

  statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [
      pkgs.jq
    ];
    text = ''
      input="$(cat)"

      model=$(jq -r '.model.display_name' <<<"$input")
      cost=$(jq -r '.cost.total_cost_usd * 100 | round / 100' <<<"$input")

      duration=$(jq -r '
        (.cost.total_duration_ms / 1000) as $seconds |
        if $seconds >= 3600 then
          "\($seconds / 3600 | floor)h\(($seconds % 3600) / 60 | floor)m"
        elif $seconds >= 60 then
          "\($seconds / 60 | floor)m\($seconds % 60 | floor)s"
        else
          "\($seconds | floor)s"
        end
      ' <<<"$input")

      added=$(jq -r '.cost.total_lines_added' <<<"$input")
      removed=$(jq -r '.cost.total_lines_removed' <<<"$input")

      project=$(jq -r '.workspace.project_dir' <<<"$input")
      current=$(jq -r '.workspace as $workspace | $workspace.current_dir | ltrimstr($workspace.project_dir)' <<<"$input")

      printf '\e[37m %s\e[0m | \e[33m$%s\e[0m | \e[34m %s\e[0m | \e[32m+%s\e[31m-%s\e[0m in \e[2;36m%s\e[1;36m%s\e[0m\n' \
        "$model" "$cost" "$duration" "$added" "$removed" "$project" "$current"
      if jj root --ignore-working-copy >/dev/null
      then
        jj lo --ignore-working-copy --color=always
      fi
    '';
  };

  claude-code-settings = json.generate "claude-code-settings.json" {
    includeCoAuthoredBy = false;
    statusLine = {
      type = "command";
      command = lib.getExe statusline;
    };
    permissions = {
      allow =
        [ "WebSearch" ] ++
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
