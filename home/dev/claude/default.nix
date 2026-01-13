{ config, lib, pkgs, ... }:
let
  claude-statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [ pkgs.jq pkgs.jujutsu ];
    text = lib.readFile ./claude-statusline.sh;
  };

  jj-claude = pkgs.writeShellApplication {
    name = "jj-claude";
    runtimeInputs = [ pkgs.coreutils pkgs.jujutsu ];
    text = lib.readFile ./jj-claude.sh;
  };

in {
  programs.claude-code = {
    enable = true;

    settings = {
      includeCoAuthoredBy = false;

      env = {
        "CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR" = "1";
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" = "1";
        "DISABLE_AUTOUPDATER" = "1";
        "DISABLE_BUG_COMMAND" = "1";
        "DISABLE_ERROR_REPORTING" = "1";
        "DISABLE_TELEMETRY" = "1";
      };

      statusLine = {
        type = "command";
        command = lib.getExe claude-statusline;
      };

      permissions = {
        defaultMode = "acceptEdits";
        allow = [
          "Bash(rg:*)"
          "Bash(fd:*)"
          "Bash(find:*)"
          "Bash(grep:*)"
          "Bash(ls:*)"
          "Bash(cat:*)"
          "Bash(head:*)"
          "Bash(tail:*)"
          "Bash(wc:*)"
          "Bash(sort:*)"
          "Bash(uniq:*)"

          "Bash(git status:*)"
          "Bash(git log:*)"
          "Bash(git show:*)"
          "Bash(git diff:*)"
          "Bash(jj status:*)"
          "Bash(jj log:*)"
          "Bash(jj show:*)"
          "Bash(jj diff:*)"
          "Bash(jj file show:*)"
          "Bash(jj bookmark list:*)"
          "Bash(jj new:*)"

          "Bash(gh browse:*)"
          "Bash(gh issue list:*)"
          "Bash(gh issue view:*)"
          "Bash(gh pr diff:*)"
          "Bash(gh pr list:*)"
          "Bash(gh pr view:*)"
          "Bash(gh repo view:*)"
          "Bash(gh status:*)"

          "Bash(nix flake check:*)"

          "Bash(cargo check:*)"
          "Bash(cargo clippy:*)"
          "Bash(cargo test:*)"

          "Bash(yamllint:*)"
          "Bash(shellcheck:*)"
        ];
      };
    };

    memory = builtins.readFile ./CLAUDE.md;

    imports = {
      jj = {
        source = ./imports/jj.md;
        description = "Jujutsu (jj) command mappings and workflow patterns";
      };
    };
  };

  # Run a claude instance in a fresh workspace
  programs.jujutsu.settings.aliases.claude = ["util" "exec" "--" (lib.getExe jj-claude)];

  programs.opencode = {
    enable = true;
    package = pkgs.unstable.opencode;

    rules = builtins.readFile ./CLAUDE.md;

    settings = {
      autoupdate = false;

      theme = "system";

      instructions = ["CONTRIBUTING.md"];

      permission = {
        "*" = "ask";

        todoread = "allow";
        todowrite = "allow";

        read = "allow";
        glob = "allow";
        grep = "allow";
        list = "allow";

        skill = "allow";

        edit = {
          "*" = "allow";
          ".jj" = "deny";
          ".git" = "deny";
        };

        bash = {
          "rg *" = "allow";
          "fd *" = "allow";
          "find *" = "allow";
          "grep *" = "allow";
          "ls *" = "allow";
          "cat *" = "allow";
          "head *" = "allow";
          "tail *" = "allow";
          "wc *" = "allow";
          "sort *" = "allow";
          "uniq *" = "allow";

          "git status *" = "allow";
          "git log *" = "allow";
          "git show *" = "allow";
          "git diff *" = "allow";
          "jj status *" = "allow";
          "jj log *" = "allow";
          "jj show *" = "allow";
          "jj diff *" = "allow";
          "jj file show *" = "allow";
          "jj bookmark list *" = "allow";
          "jj new *" = "allow";

          "gh browse *" = "allow";
          "gh issue list *" = "allow";
          "gh issue view *" = "allow";
          "gh pr diff *" = "allow";
          "gh pr list *" = "allow";
          "gh pr view *" = "allow";
          "gh repo view *" = "allow";
          "gh status *" = "allow";

          "nix flake check *" = "allow";

          "cargo check *" = "allow";
          "cargo clippy *" = "allow";
          "cargo test *" = "allow";

          "yamllint *" = "allow";
          "shellcheck *" = "allow";
        };
      };

      keybinds = {
        leader = "ctrl+t";

        app_exit = "<leader>q";

        session_export = "none";
        session_new = "none";
        session_list = "none";
        session_timeline = "none";
        session_compact = "none";

        session_child_cycle = "<leader>l";
        session_child_cycle_reverse = "<leader>h";

        session_parent = "<leader>k";

        messages_half_page_up = "ctrl+u";
        messages_half_page_down = "ctrl+d";
      };
    };
  };
}
