{ lib, config, pkgs, ... }:
let
  gh-pr-list-popup = pkgs.writeShellApplication {
    name = "gh-pr-list-popup";
    runtimeInputs = with pkgs; [ ncurses ];
    text = ''
      trap exit SIGINT
      trap "printf '\e[?25h'" EXIT
      printf '\e[?25l'

      # pinned to the last row so it doesn't float with the list length
      statusline() {
        printf '\e[%s;1H\e[48;5;18m\e[38;5;20m  %s  \e[K\e[0m' "$(tput lines)" "$1"
      }

      while true
      do
        statusline 'refreshing…'
        # render first, then repaint, so refreshes don't flicker
        output="$("${config.binHome}/gh-pr-list" "$@" 2>&1 || true)"
        printf '\e[H\e[2J%s' "$output"
        statusline '[r: refresh]  [any key: close]'

        # timeout doubles as a slow auto-refresh
        if read -rsn1 -t 60 key
        then
          [[ $key == r ]] || exit
        fi
      done
    '';
  };
in {
  scripts.gh-pr-list = {
    runtimeInputs = with pkgs; [ gh jq coreutils ncurses ];
    source = ./gh-pr-list.sh;
  };

  programs = {
    gh = {
      enable = true;
      settings = {
        prompt = "enabled";
        aliases = {
          co = "pr checkout --detach";
          conflicts = ''
            pr list --json number,title,mergeable,headRefName --jq '.[] | select(.mergeable == "CONFLICTING") | "\(.number) \(.headRefName): \(.title)"'
          '';
        };
      };
    };
  };

  programs.tmux.extraConfig = lib.mkAfter ''
    bind-key P display-popup -d '#{pane_current_path}' -w 90% -h 40% -E "${lib.getExe gh-pr-list-popup}"
  '';

  # Fuck 16-bit color codes
  home.sessionVariables.GLAMOUR_STYLE = "ascii";
}
