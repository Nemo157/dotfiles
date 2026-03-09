{ config, lib, pkgs, ... }:
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

in {
  age.secrets.gcal-oauth-credentials.file = ../gcal-oauth-credentials.age;

  services.mcp-proxy = {
    enable = true;
    path = [ pkgs.nodejs ];
    port = 14127;
    servers.google-calendar = {
      command = [ "npx" "-y" "@cocal/google-calendar-mcp" ];
      env = {
        GOOGLE_OAUTH_CREDENTIALS = config.age.secrets.gcal-oauth-credentials.path;
        ENABLED_TOOLS = "list-calendars,list-events,search-events,get-event,get-freebusy,get-current-time";
      };
    };
  };

  programs.claude-code = {
    settings = {
      permissions.allow = lib.mkAfter [
        "WebSearch"
        "Skill(linear-cli)"
        "Bash(linear issue list:*)"
        "Bash(linear issue view:*)"
        "Bash(linear issue id:*)"
        "Bash(linear issue title:*)"
        "Bash(linear issue url:*)"
        "Bash(linear issue describe:*)"
        "Bash(linear team list:*)"
        "Bash(linear team id:*)"
        "Bash(linear team members:*)"
        "Bash(linear project list:*)"
        "Bash(linear project view:*)"

        "Skill(brain-file)"

        "Bash(jj -R ~/.local/share/second-brain:*)"
        "Bash(mkdir -p ~/.local/share/second-brain:*)"
        "Bash(ls ~/.local/share/second-brain:*)"
        "Bash(cat ~/.local/share/second-brain:*)"

        "Bash(date:*)"

        "Bash(gh search issues:*)"
        "Bash(gh search prs:*)"
        "Bash(gh search code:*)"

        "Bash(gh-pr-activity:*)"
        "Bash(gh-issue-activity:*)"
      ];
    };

    memory = lib.mkAfter ("\n\n" + builtins.readFile ./CLAUDE.md);

    imports = {
      second-brain = {
        source = ./imports/second-brain.md;
        description = "Second brain detection rules — when to file information";
      };
    };

    skills = {
      linear-cli = {
        description = "Use the linear CLI tool to query Linear data and retrieve issues, teams, or project information";
        allowed-tools = [
          "Bash(linear issue list:*)"
          "Bash(linear issue view:*)"
          "Bash(linear issue id:*)"
          "Bash(linear issue title:*)"
          "Bash(linear issue url:*)"
          "Bash(linear issue describe:*)"
          "Bash(linear team list:*)"
          "Bash(linear team id:*)"
          "Bash(linear team members:*)"
          "Bash(linear project list:*)"
          "Bash(linear project view:*)"
        ];
        source = ./skills/linear-cli.md;
      };
      brain-file = {
        description = "File information into the second brain — daily entries, tasks, people, projects, decisions";
        allowed-tools = [
          "Bash(jj -R ~/.local/share/second-brain:*)"
          "Bash(mkdir -p ~/.local/share/second-brain:*)"
          "Bash(ls ~/.local/share/second-brain:*)"
          "Bash(cat ~/.local/share/second-brain:*)"
        ];
        source = ./skills/brain-file.md;
      };
    };
  };

  programs.opencode = {
    rules = lib.mkAfter ("\n\n" + builtins.readFile ./CLAUDE.md + "\n\n" + builtins.readFile ./imports/second-brain.md);

    commands = {
      brain-sync = builtins.readFile ./commands/brain-sync.md;
      brain-investigate = builtins.readFile ./commands/brain-investigate.md;
      brain-recap = builtins.readFile ./commands/brain-recap.md;
      brain-todos = builtins.readFile ./commands/brain-todos.md;
      daily = builtins.readFile ./commands/daily.md;
    };

    settings = {
      mcp = {
        google-calendar = {
          type = "remote";
          url = "http://127.0.0.1:14127/servers/google-calendar/sse";
        };
      };

      tools = {
        "google-calendar_*" = false;
      };

      agent.brain = {
        description = "Query and modify the second brain — direct operations on journal entries, tasks, people, projects, and decisions, probably unrelated to the current project";
        prompt = ''
          You are an agent for directly querying and modifying the second brain at `~/.local/share/second-brain/`.
          This is a jj-managed, Obsidian-compatible personal knowledge vault.

          You handle tasks like:
          - Searching for or reading specific entries (daily journal, tasks, people, projects, decisions)
          - Creating or updating entries
          - Answering questions about what's in the brain
          - Running sync operations (filling gaps from GitHub/Linear/Calendar, generating rollups)

          Your work is likely unrelated to whatever project the user is currently working in, but may be tangentially related (e.g. filing a decision made in the current project context).

          Load the `brain-file` skill when you need to create or update entries to follow the correct formats and conventions.
        '';
        tools = {
          "google-calendar_*" = true;
        };
      };

      permission = {
        external_directory = {
          "~/.local/share/second-brain/**" = "allow";
        };

        bash = {
          "linear issue list *" = "allow";
          "linear issue view *" = "allow";
          "linear issue id *" = "allow";
          "linear issue title *" = "allow";
          "linear issue url *" = "allow";
          "linear issue describe *" = "allow";
          "linear team list *" = "allow";
          "linear team id *" = "allow";
          "linear team members *" = "allow";
          "linear project list *" = "allow";
          "linear project view *" = "allow";

          "jj -R ~/.local/share/second-brain *" = "allow";
          "mkdir -p ~/.local/share/second-brain *" = "allow";

          "date *" = "allow";

          "gh search issues *" = "allow";
          "gh search prs *" = "allow";
          "gh search code *" = "allow";

          "gh-pr-activity *" = "allow";
          "gh-issue-activity *" = "allow";
        };

        webfetch = "allow";
        websearch = "allow";
      };
    };
  };

  services.opencode.path = [ gh-pr-activity gh-issue-activity ];

  xdg.configFile = {
    "opencode/skill/linear-cli/SKILL.md".source = config.xdg.configFile."claude/skills/linear-cli/SKILL.md".source;
    "opencode/skill/brain-file/SKILL.md".source = config.xdg.configFile."claude/skills/brain-file/SKILL.md".source;
  };
}
