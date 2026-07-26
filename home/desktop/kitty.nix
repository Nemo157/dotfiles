{ lib, config, pkgs, ... }:
let
  kitty-shell = pkgs.writeShellApplication {
    name = "kitty-tmux-session";
    runtimeInputs = [
      pkgs.zsh
      pkgs.tmux
    ];
    text = ''
        zsh --login -c "tmux -u new-session -s primary-$(hostname -s) -t primary -A"
    '';
  };

  mkTheme = palette: ''
    background #${palette.base00}
    foreground #${palette.base05}
    selection_background #${palette.base03}
    selection_foreground #${palette.base05}

    cursor #${palette.base05}
    cursor_text_color #${palette.base00}

    color0 #${palette.base00}
    color1 #${palette.base08}
    color2 #${palette.base0B}
    color3 #${palette.base0A}
    color4 #${palette.base0D}
    color5 #${palette.base0E}
    color6 #${palette.base0C}
    color7 #${palette.base05}

    color8 #${palette.base02}
    color9 #${palette.base08}
    color10 #${palette.base0B}
    color11 #${palette.base0A}
    color12 #${palette.base0D}
    color13 #${palette.base0E}
    color14 #${palette.base0C}
    color15 #${palette.base07}

    color16 #${palette.base09}
    color17 #${palette.base0F}
    color18 #${palette.base01}
    color19 #${palette.base02}
    color20 #${palette.base04}
    color21 #${palette.base06}
  '';

in {
  programs.kitty = {
    enable = true;

    font = {
      name = "FiraCode Nerd Font";
      size = 11.0;
    };

    shellIntegration = {
      mode = "disabled";
    };

    settings = {
      enable_audio_bell = false;

      # Disable kitty's auto config-reload: Home Manager swaps the kitty.conf
      # symlink every apply, which triggers a reload by default.
      # Kitty's auto-theme (`.auto.conf`) re-application on a config reload is buggy
      # (kovidgoyal/kitty#8203, #8354, #8530, #8448).
      auto_reload_config = -1;

      window_border_width = 0;
      window_padding_width = "0 2";
      placement_strategy = "top-left";

      scrollback_lines = 0;

      dim_opacity = "0.8";

      shell = lib.getExe kitty-shell;
    } // lib.optionalAttrs pkgs.stdenv.isLinux {
      allow_remote_control = "socket-only";
      listen_on = "unix:$XDG_RUNTIME_DIR/kitty-{kitty_pid}.socket";
    };

    # Kitty→tmux handling of extended keys is buggy,
    # force it to send what tmux expects no matter the state
    keybindings = {
      "shift+enter" = "send_text all \\x1b[13;2u";
      "ctrl+enter" = "send_text all \\x1b[13;5u";
    };

    extraConfig = ''
      symbol_map U+1F600 ferris-icons
    '';
  };

  xdg.configFile = {
    "kitty/dark-theme.auto.conf".text = mkTheme config.colorSchemes.dark.palette;
    "kitty/light-theme.auto.conf".text = mkTheme config.colorSchemes.light.palette;
    "kitty/no-preference-theme.auto.conf".text = mkTheme config.colorSchemes.dark.palette;

    # Default sends SIGUSR1 to every running kitty window whenever kitty.conf is regenerated.
    # This is supposed to do a config reload, but that's buggy as above, and also it seems to kill
    # the window instead.
    "kitty/kitty.conf".onChange = lib.mkForce "";
  };
}

