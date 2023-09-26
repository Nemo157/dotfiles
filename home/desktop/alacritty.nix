{ lib, config, pkgs, ... }:
let
  colors = let
    sol = (import ../sol.nix);
    common = ({ primary, normal, bright }: with sol; {
      inherit primary;
      cursor = {
        text = primary.background;
        cursor = primary.foreground;
      };
      normal = {
        inherit red green yellow blue magenta cyan;
      } // normal;
      bright = {
        red = orange;
        green = base1;
        yellow = base0;
        blue = base00;
        magenta = violet;
        cyan = base01;
      } // bright;
    });
  in {
    dark = with sol; common {
      primary = {
        background = base03;
        foreground = base0;
      };
      normal = {
        black = base02;
        white = base2;
      };
      bright = {
        black = base03;
        white = base3;
      };
    };
    light = with sol; common {
      primary = {
        background = base3;
        foreground = base00;
      };
      normal = {
        black = base2;
        white = base02;
      };
      bright = {
        black = base3;
        white = base03;
      };
    };
  };
  alacritty = lib.getExe config.programs.alacritty.package;
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

      colors = colors.dark;
    };
  };
} // {
  xdg.dataFile = lib.attrsets.mapAttrs' (mode: colors: {
    name = "${mode}-mode.d/alacritty-${mode}.sh";
    value = {
      # onChange = "${pkgs.systemd}/bin/systemctl --user restart darkman";
      source = pkgs.writeShellScript "alacritty-${mode}.sh" ''
        ${alacritty} msg config colors=${lib.escapeShellArg (builtins.toJSON colors)}
      '';
    };
  }) colors;
}
