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
  imports = [
    ./module.nix
  ];

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

    agents = {
      code-reviewer.source = ./agents/code-reviewer.md;
      technical-docs-reviewer.source = ./agents/technical-docs-reviewer.md;
    };

    imports = {
      jj = {
        source = ./imports/jj.md;
        description = "Jujutsu (jj) command mappings and workflow patterns";
      };
    };
  };

  # Run a claude instance in a fresh workspace
  programs.jujutsu.settings.aliases.claude = ["util" "exec" "--" (lib.getExe jj-claude)];
}
