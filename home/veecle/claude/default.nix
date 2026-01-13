{ config, lib, pkgs, ... }: {
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
      ];
    };

    memory = lib.mkAfter ("\n\n" + builtins.readFile ./CLAUDE.md);

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
    };
  };

  programs.opencode = {
    rules = lib.mkAfter ("\n\n" + builtins.readFile ./CLAUDE.md);
  };

  xdg.configFile."opencode/skill/linear-cli/SKILL.md".source = config.xdg.configFile."claude/skills/linear-cli/SKILL.md".source;
}
