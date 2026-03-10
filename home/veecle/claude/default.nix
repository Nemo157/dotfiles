{ config, lib, pkgs, ... }:
{
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

        "Bash(date:*)"

        "Bash(gh search issues:*)"
        "Bash(gh search prs:*)"
        "Bash(gh search code:*)"
      ];
    };

    memory = lib.mkAfter ("\n\n" + builtins.readFile ./CLAUDE.md);
  };

  programs.opencode = {
    rules = lib.mkAfter ("\n\n" + builtins.readFile ./CLAUDE.md);

    commands.brain-sync = lib.mkAfter ''

      ## GitHub Org

      Use `--owner=veecle` for all `gh search` commands in this workflow.
    '';

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
        # Blocked on <https://github.com/anomalyco/opencode/issues/7377>
        # slack = {
        #   type = "remote";
        #   url = "https://mcp.slack.com/mcp";
        #   oauth = {
        #     # Claude's clientId :eyes:
        #     clientId = "1601185624273.8899143856786";
        #     redirectUri = "http://127.0.0.1:3118/mcp/oauth/callback;
        #   };
        # };
      };

      tools = {
        "google-calendar_*" = false;
        "linear_*" = false;
      };

      agent.linear = {
        mode = "subagent";
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

      permission = {
        task = {
          "linear" = "allow";
        };

        webfetch = "allow";
        websearch = "allow";
      };
    };
  };
}
