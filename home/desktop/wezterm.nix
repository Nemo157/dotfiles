{ lib, config, pkgs, ... }: {
  programs.wezterm = {
    enable = true;

    enableBashIntegration = false;
    enableZshIntegration = false;

    colorSchemes = with (import ../sol.nix); {
      sol-dark = rec {
        foreground = base0;
        background = base03;

        ansi = [
          base02 red green yellow
          blue magenta cyan base2
        ];
        brights = [
          base03 orange base1 base0
          base00 violet base01 base3
        ];

        cursor_bg = foreground;
        cursor_border = foreground;
        cursor_fg = background;

        selection_bg = foreground;
        selection_fg = background;
      };
      sol-light = rec {
        foreground = base00;
        background = base3;

        ansi = [
          base2 red green yellow
          blue magenta cyan base02
        ];
        brights = [
          base3 red green yellow
          blue magenta cyan base03
        ];

        cursor_bg = foreground;
        cursor_border = foreground;
        cursor_fg = background;

        selection_bg = foreground;
        selection_fg = background;
      };
    };

    extraConfig = ''
      local config = wezterm.config_builder()

      local appearance = 'Dark'
      if wezterm.gui then
        appearance = wezterm.gui.get_appearance()
      end

      if appearance:find 'Dark' then
        config.color_scheme = 'sol-dark'
      else
        config.color_scheme = 'sol-light'
      end

      config.font = wezterm.font 'FiraCode Nerd Font'
      config.font_size = 11.0

      config.audible_bell = "Disabled"

      config.scrollback_lines = 0
      config.enable_tab_bar = false

      config.bold_brightens_ansi_colors = "No"
      config.check_for_updates = false

      config.default_prog = {
        "zsh",
        "--login",
        "-c",
        "tmux -u new-session -s primary-$(hosttname -s) -t primary -A",
      }

      config.window_padding = {
          left = 2,
          right = 2,
          bottom = 0,
          top = 0,
      }

      return config
    '';
  };
}

