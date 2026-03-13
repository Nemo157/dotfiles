{ lib, pkgs, ... }:
let
  gh-pr-activity = pkgs.writeShellApplication {
    name = "gh-pr-activity";
    runtimeInputs = [ pkgs.gh pkgs.jq pkgs.coreutils ];
    text = lib.readFile ./gh-pr-activity.sh;
  };

  gh-issue-activity = pkgs.writeShellApplication {
    name = "gh-issue-activity";
    runtimeInputs = [ pkgs.gh pkgs.jq pkgs.coreutils ];
    text = lib.readFile ./gh-issue-activity.sh;
  };

# Inspired by https://conradludgate.com/posts/cursor-workflows
in {
  programs.opencode = {
    rules = lib.mkAfter ("\n\n" + builtins.readFile ./imports/second-brain.md);

    commands = {
      brain-sync = builtins.readFile ./commands/brain-sync.md;
      brain-investigate = builtins.readFile ./commands/brain-investigate.md;
      brain-recap = builtins.readFile ./commands/brain-recap.md;
      brain-todos = builtins.readFile ./commands/brain-todos.md;
      daily = builtins.readFile ./commands/daily.md;
    };

    settings = {
      agent.brain-file = {
        mode = "subagent";
        hidden = true;
        description = "File information into the second brain — daily journal entries, tasks, people, projects, and decision records";
        prompt = builtins.readFile ./agents/brain-file.md;

        tools = {
          lsp = false;
          task = false;
          skill = false;
          webfetch = false;
          question = false;
          todoread = false;
          todowrite = false;
        };

        permission = {
          edit = {
            "*" = "deny";
            "~/.local/share/second-brain/**" = "allow";
          };
          bash = {
            "*" = "deny";
            "jj -R ~/.local/share/second-brain *" = "allow";
            "mkdir -p ~/.local/share/second-brain *" = "allow";
            "date *" = "allow";
          };
        };
      };

      agent.brain = {
        mode = "primary";
        description = "Query and modify the second brain — direct operations on journal entries, tasks, people, projects, and decisions, probably unrelated to the current project";
        prompt = ''
          You are an agent for directly querying and modifying the second brain at `~/.local/share/second-brain/`.
          This is a jj-managed, Obsidian-compatible personal knowledge vault.

          You handle tasks like:
          - Searching for or reading specific entries (daily journal, tasks, people, projects, decisions)
          - Creating or updating entries
          - Answering questions about what's in the brain
          - Running sync operations (filling gaps from GitHub/Calendar, generating rollups)
          - Querying Linear via the `linear` agent for issue lookups and cross-referencing

          Your work is likely unrelated to whatever project the user is currently working in, but may be tangentially related (e.g. filing a decision made in the current project context).

          Invoke the `brain-file` subagent via the Task tool when you need to create or update entries — it handles all filing formats and conventions.
        '';
        tools = {
          "google-calendar_*" = true;
          "slack_slack_search_public" = true;
          "slack_slack_search_public_and_private" = true;
          "slack_slack_search_channels" = true;
          "slack_slack_search_users" = true;
          "slack_slack_read_channel" = true;
          "slack_slack_read_thread" = true;
          "slack_slack_read_user_profile" = true;
        };
      };

      permission = {
        task = {
          "brain-file" = "allow";
        };

        external_directory = {
          "~/.local/share/second-brain/**" = "allow";
        };

        bash = {
          "jj -R ~/.local/share/second-brain *" = "allow";
          "mkdir -p ~/.local/share/second-brain *" = "allow";

          "date *" = "allow";

          "gh search issues *" = "allow";
          "gh search prs *" = "allow";
          "gh search code *" = "allow";

          "gh-pr-activity *" = "allow";
          "gh-issue-activity *" = "allow";
        };
      };
    };
  };

  services.opencode.path = [ gh-pr-activity gh-issue-activity ];

}
