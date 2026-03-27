{ lib, ... }:
{
  programs.claude-code = {
    settings = {
      mcpServers = {
        linear = {
          type = "http";
          url = "https://mcp.linear.app/mcp";
        };
        slack = {
          type = "http";
          url = "https://mcp.slack.com/mcp";
          oauth = {
            clientId = "1601185624273.8899143856786";
            callbackPort = 3118;
          };
        };
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
}
