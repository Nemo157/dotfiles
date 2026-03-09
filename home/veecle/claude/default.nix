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

        "Skill(brain-file)"

        "Bash(jj -R ~/.local/share/second-brain:*)"
        "Bash(mkdir -p ~/.local/share/second-brain:*)"
        "Bash(ls ~/.local/share/second-brain:*)"
        "Bash(cat ~/.local/share/second-brain:*)"

        "Bash(date:*)"

        "Bash(gh search issues:*)"
        "Bash(gh search prs:*)"
        "Bash(gh search code:*)"
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
        };

        webfetch = "allow";
        websearch = "allow";
      };
    };
  };

  xdg.configFile = {
    "opencode/skill/linear-cli/SKILL.md".source = config.xdg.configFile."claude/skills/linear-cli/SKILL.md".source;
    "opencode/skill/brain-file/SKILL.md".source = config.xdg.configFile."claude/skills/brain-file/SKILL.md".source;
  };
}
