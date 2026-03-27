{ config, lib, pkgs, ... }:
let
  log-problem = pkgs.writeShellApplication {
    name = "log-problem";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if [ $# -lt 2 ]; then
        echo "Usage: log-problem <project> <description>" >&2
        exit 1
      fi

      project="$1"
      shift
      description="$*"

      log_file="''${XDG_DATA_HOME:-$HOME/.local/share}/opencode/problems.md"
      mkdir -p "$(dirname "$log_file")"

      {
        echo ""
        echo "## $(date --iso-8601=seconds) — $project"
        echo ""
        echo "$description"
      } >> "$log_file"
    '';
  };

in {
  age.secrets.opencode-server-password.file = ./opencode-server-password.age;

  programs.opencode = {
    enable = true;

    rules = (builtins.readFile ../claude/CLAUDE.md) + ''
      Most projects will have a `.envrc` providing project-specific tools, you need to use `direnv exec` to run these.
      General system or broadly used development tools do not need this and should be available in the environment directly.
    '';

    commands = {
      retrospective = builtins.readFile ./commands/retrospective.md;
    };

    settings = {
      autoupdate = false;

      theme = "system";

      instructions = ["CONTRIBUTING.md"];

      enabled_providers = [
        "anthropic"
        "openrouter"
      ];

      permission = {
        # Workaround: "*" = "ask" overrides tools deny rules due to
        # https://github.com/anomalyco/opencode/issues/15664
        # so we explicitly set each unmentioned tool to "ask" instead.
        webfetch = lib.mkDefault "ask";
        websearch = lib.mkDefault "ask";
        codesearch = lib.mkDefault "ask";

        todoread = "allow";
        todowrite = "allow";

        read = "allow";
        glob = "allow";
        grep = "allow";
        list = "allow";

        skill = "allow";
        lsp = "allow";

        task = {
          "explore" = "allow";
        };

        edit = {
          "*" = "allow";
          ".jj" = "deny";
          ".git" = "deny";
        };

        bash = {
          "*" = "ask";

          "rg *" = "allow";
          "fd *" = "allow";
          "find *" = "allow";
          "grep *" = "allow";
          "ls *" = "allow";
          "echo *" = "allow";
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

          "log-problem *" = "allow";
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

        messages_first = "ctrl+g";
        messages_last = "ctrl+shift+g";
        messages_half_page_up = "ctrl+u";
        messages_half_page_down = "ctrl+d";

        messages_toggle_conceal = "none";
      };

      agent = {
        explore = {
          permission = {
            task = "deny";
          };
        };

        general = {
          permission = {
            task = "deny";
          };
        };

        ask = {
          description = "Readonly agent for answering codebase questions";
          mode = "primary";
          prompt = ''
            You are a codebase exploration assistant. Your role is to answer questions about the codebase succinctly and accurately.

            ## Guidelines
            - Search and read code to understand the codebase structure and implementation
            - Provide concise, direct answers with file:line references
            - Do not make any modifications - you are readonly
            - Focus on explaining what exists, not suggesting changes unless asked
            - When answering, cite specific code locations
          '';
          permission = {
            edit = "deny";
            bash = "ask";
          };
        };

        ask-external = {
          description = "Answer general questions not related to the current codebase";
          mode = "primary";
          prompt = ''
            You are a knowledgeable assistant for answering general programming, technology, and conceptual questions that are not directly related to the current codebase.

            ## Guidelines
            - Answer questions using your training knowledge and web searches
            - Do not read or modify any files in the codebase
            - Provide concise, direct answers with examples where helpful
            - When relevant, link to official documentation or references
          '';
          tools = {
            read = false;
            edit = false;
            glob = false;
            grep = false;
            list = false;
            lsp = false;
            task = false;
            skill = false;
          };
          permission = {
            edit = "deny";
            bash = "deny";
          };
        };
      };
    };
  };

  services.opencode = {
    enable = true;
    package = pkgs.unstable.opencode;
    environmentFile = config.age.secrets.opencode-server-password.path;
    path = [ log-problem ];
  };

}
