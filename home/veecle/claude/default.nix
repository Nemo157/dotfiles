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
      mcpServers.linear = {
        type = "http";
        url = "https://mcp.linear.app/mcp";
      };

      permissions.allow = lib.mkAfter [
        "WebSearch"

        "mcp__linear__get_document"
        "mcp__linear__get_issue"
        "mcp__linear__get_issue_status"
        "mcp__linear__get_project"
        "mcp__linear__get_team"
        "mcp__linear__get_user"
        "mcp__linear__list_comments"
        "mcp__linear__list_cycles"
        "mcp__linear__list_documents"
        "mcp__linear__list_issue_labels"
        "mcp__linear__list_issue_statuses"
        "mcp__linear__list_issues"
        "mcp__linear__list_my_issues"
        "mcp__linear__list_project_labels"
        "mcp__linear__list_projects"
        "mcp__linear__list_teams"
        "mcp__linear__list_users"
        "mcp__linear__search_documentation"

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
        linear = {
          type = "remote";
          url = "https://mcp.linear.app/mcp";
        };
      };

      tools = {
        "google-calendar_*" = false;
        "linear_*" = false;
      };

      agent.linear = {
        description = "Query Linear issues, projects, teams, and other data — use this for any Linear lookups";
        prompt = ''
          You are a Linear query agent. Your job is to fetch data from Linear and return concise, structured results.

          ## Guidelines
          - Linear MCP tools return large JSON responses — use jq via Bash to extract the specific fields callers need
          - When fetching issues: extract id, identifier, title, state, assignee, priority, and description
          - When fetching lists: extract the key identifying fields, not full objects
          - Return results as compact structured text, not raw JSON dumps
          - If a query returns no results, say so clearly

          ## Workflow
          1. Use the appropriate `linear_*` MCP tool to fetch data
          2. If the response is large, pipe it through `jq` to extract relevant fields
          3. Return a concise summary to the caller

          ## Example jq patterns
          - Issue summary: `jq '{id, identifier, title, state: .state.name, assignee: .assignee.name}' response.json`
          - Issue list: `jq '[.[] | {identifier, title, state: .state.name}]' response.json`
        '';
        tools = {
          "linear_get_document" = true;
          "linear_get_issue" = true;
          "linear_get_issue_status" = true;
          "linear_get_project" = true;
          "linear_get_team" = true;
          "linear_get_user" = true;
          "linear_list_comments" = true;
          "linear_list_cycles" = true;
          "linear_list_documents" = true;
          "linear_list_issue_labels" = true;
          "linear_list_issue_statuses" = true;
          "linear_list_issues" = true;
          "linear_list_my_issues" = true;
          "linear_list_project_labels" = true;
          "linear_list_projects" = true;
          "linear_list_teams" = true;
          "linear_list_users" = true;
          "linear_search_documentation" = true;
        };
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
          - Running sync operations (filling gaps from GitHub/Calendar, generating rollups)
          - Querying Linear via the `linear` agent for issue lookups and cross-referencing

          Your work is likely unrelated to whatever project the user is currently working in, but may be tangentially related (e.g. filing a decision made in the current project context).

          Load the `brain-file` skill when you need to create or update entries to follow the correct formats and conventions.
        '';
        tools = {
          "google-calendar_*" = true;
        };
      };

      permission = {
        task = {
          "linear" = "allow";
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

        webfetch = "allow";
        websearch = "allow";
      };
    };
  };

  services.opencode.path = [ gh-pr-activity gh-issue-activity ];

  xdg.configFile = {
    "opencode/skill/brain-file/SKILL.md".source = config.xdg.configFile."claude/skills/brain-file/SKILL.md".source;
  };
}
