{ lib, config, pkgs, ... }:
let
  kitty-shell = pkgs.writeShellApplication {
    name = "kitty-tmux-session";
    text = ''
        zsh --login -c "tmux -u new-session -s primary-$(hosttname -s) -t primary -A"
    '';
  };

  color-schemes = with (import ../sol.nix); {
    dark = pkgs.writeText "kitty-dark.conf" ''
      foreground ${base0}
      background ${base03}
      selection_foreground ${base03}
      selection_background ${base0}

      color0 ${base02}
      color1 ${red}
      color2 ${green}
      color3 ${yellow}
      color4 ${blue}
      color5 ${magenta}
      color6 ${cyan}
      color7 ${base2}

      color8 ${base03}
      color9 ${orange}
      color10 ${base1}
      color11 ${base0}
      color12 ${base00}
      color13 ${violet}
      color14 ${base01}
      color15 ${base3}

      cursor ${base0}
      cursor_text_color ${base03}
    '';

    light = pkgs.writeText "kitty-light.conf" ''
      foreground ${base00}
      background ${base3}
      selection_foreground ${base3}
      selection_background ${base00}

      color0 ${base2}
      color1 ${red}
      color2 ${green}
      color3 ${yellow}
      color4 ${blue}
      color5 ${magenta}
      color6 ${cyan}
      color7 ${base02}

      color8 ${base3}
      color9 ${orange}
      color10 ${base01}
      color11 ${base00}
      color12 ${base0}
      color13 ${violet}
      color14 ${base1}
      color15 ${base03}

      cursor ${base00}
      cursor_text_color ${base3}
    '';
  };
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

      window_border_width = 0;
      window_padding_width = "0 2";
      placement_strategy = "top-left";

      scrollback_lines = 0;

      dim_opacity = "0.8";

      shell = lib.getExe kitty-shell;

      allow_remote_control = "socket-only";
      listen_on = "unix:$XDG_RUNTIME_DIR/kitty-{kitty_pid}.socket";
    };

    keybindings = {
      "shift+enter" = "send_text all \\x1b\\x0a";
    };

    extraConfig = ''
      include ${color-schemes.light}

      symbol_map U+1F600 ferris-icons
    '';
  };

  xdg.dataFile = lib.attrsets.mapAttrs' (mode: file: {
    name = "${mode}-mode.d/kitty-${mode}.sh";
    value = {
      source = pkgs.writeShellScript "kitty-${mode}.sh" ''
        for socket in $XDG_RUNTIME_DIR/kitty-*.socket
        do
          ${lib.getExe' pkgs.kitty "kitten"} @ --to unix:$socket set-colors -a ${file}
        done
      '';
    };
  }) color-schemes;
}

