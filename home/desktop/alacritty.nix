{ lib, config, pkgs, ... }:
let
  sol = (import ../sol.nix);
in {
  programs.alacritty = {
    enable = true;

    settings = {
      window.padding = { x = 0; y = 0; };

      scrolling.history = 0;

      font = {
        normal.family = "FiraCode Nerd Font";
        size = 11.0;
      };

      bell.duration = 0;

      draw_bold_text_with_bright_colors = false;

      mouse = {
        double_click.threshold = 300;
        triple_click.threshold = 300;
        hide_when_typing = true;
      };

      hints.url = {
        launcher = "open";
        modifiers = "Command";
      };

      selection.semantic_escape_chars = ",│`|:\"' ()[]{}<>";

      shell = {
        program = "zsh";
        args = [
          "--login"
          "-c"
          "tmux -u new-session -s master-$(hostname -s) -t master -A"
        ];
      };

      colors = with sol; {
        primary = {
          background = base03;
          foreground = base0;
        };
        cursor = {
          text = base03;
          cursor = base0;
        };
        normal = {
          inherit red green yellow blue magenta cyan;
          black = base02;
          white = base2;
        };
        bright = {
          black = base03;
          red = orange;
          green = base1;
          yellow = base0;
          blue = base00;
          magenta = violet;
          cyan = base01;
          white = base3;
        };
      };
    };
  };
}
