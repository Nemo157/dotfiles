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

  programs.opencode = {
    context = lib.mkAfter ("\n\n" + builtins.readFile ../claude/CLAUDE.md);

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
        slack = {
          type = "remote";
          url = "https://mcp.slack.com/mcp";
          oauth = {
            # Claude's clientId :eyes:
            clientId = "1601185624273.8899143856786";
            # Blocked on <https://github.com/anomalyco/opencode/issues/7377>
            # But until it can natively complete oauth, you can do oauth with claude-code then copy
            # the token across to give it access.
            # redirectUri = "http://127.0.0.1:3118/mcp/oauth/callback;
          };
        };
        vercel = {
          type = "remote";
          url = "https://mcp.vercel.com";
        };
      };

      agent = {
        linear = {
          model = "anthropic/claude-sonnet-4-6";
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

          permission = {
            "*" = "deny";

            linear_get_document = "allow";
            linear_get_issue = "allow";
            linear_get_issue_status = "allow";
            linear_get_project = "allow";
            linear_get_team = "allow";
            linear_get_user = "allow";
            linear_list_comments = "allow";
            linear_list_cycles = "allow";
            linear_list_documents = "allow";
            linear_list_issue_labels = "allow";
            linear_list_issue_statuses = "allow";
            linear_list_issues = "allow";
            linear_list_my_issues = "allow";
            linear_list_project_labels = "allow";
            linear_list_projects = "allow";
            linear_list_teams = "allow";
            linear_list_users = "allow";
            linear_search_documentation = "allow";
          };
        };

        vercel = {
          model = "anthropic/claude-sonnet-4-6";
          mode = "subagent";
          description = "Query Vercel data";
          permission = {
            "vercel_*" = "deny";
            vercel_search_vercel_documentation = "allow";
            vercel_list_projects = "allow";
            vercel_get_project = "allow";
            vercel_list_deployments = "allow";
            vercel_get_deployment = "allow";
            vercel_get_deployment_build_logs = "allow";
            vercel_get_runtime_logs = "allow";
            vercel_get_access_to_vercel_url = "allow";
            vercel_web_fetch_vercel_url = "ask";
            vercel_list_teams = "allow";
            vercel_list_toolbar_threads = "allow";
            vercel_get_toolbar_thread = "allow";
          };
        };

        general = {
          permission = {
            task = {
              linear = "allow";
            };
          };
        };
      };

      permission = {
        task = {
          linear = "allow";
        };

        webfetch = "allow";
        websearch = "allow";

        "google-calendar_*" = "deny";
        "linear_*" = "deny";
        "slack_*" = "deny";
        "vercel_*" = "deny";
      };
    };
  };
}
