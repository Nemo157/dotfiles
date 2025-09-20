{ config, lib, pkgs, ... }: {
  programs.claude-code = {
    settings = {
      permissions.allow = lib.mkAfter [
        "WebSearch"
        "mcp__linear-server__get_document"
        "mcp__linear-server__get_issue"
        "mcp__linear-server__get_issue_status"
        "mcp__linear-server__get_project"
        "mcp__linear-server__get_team"
        "mcp__linear-server__get_user"
        "mcp__linear-server__list_comments"
        "mcp__linear-server__list_cycles"
        "mcp__linear-server__list_documents"
        "mcp__linear-server__list_issue_labels"
        "mcp__linear-server__list_issue_statuses"
        "mcp__linear-server__list_issues"
        "mcp__linear-server__list_my_issues"
        "mcp__linear-server__list_project_labels"
        "mcp__linear-server__list_projects"
        "mcp__linear-server__list_teams"
        "mcp__linear-server__list_users"
        "mcp__linear-server__search_documentation"
      ];
    };

    memory = lib.mkAfter ("\n\n" + builtins.readFile ./CLAUDE.md);
  };
}
