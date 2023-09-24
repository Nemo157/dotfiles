{ lib, config, pkgs, ... }:
let
  mod = config.wayland.windowManager.sway.config.modifier;
  sol = (import ../sol.nix);
in {
  programs.wofi.enable = true;

  wayland.windowManager.sway = {
    enable = true;

    extraOptions = [
      "--unsupported-gpu"
    ];

    extraSessionCommands = ''
      export WLR_NO_HARDWARE_CURSORS=1
      # export WLR_RENDERER=vulkan
      export MOZ_ENABLE_WAYLAND=1
      export MOZ_USE_XINPUT2=1
      export NIXOS_OZONE_WL=1
    '';

    config = {
      input = {
        "*" = {
          xkb_layout = "us";
          xkb_variant = "dvp";
          xkb_options = "caps:escape,compose:ralt";
        };
      };

      terminal = "alacritty";

      fonts = {
        names = ["monospace"];
        size = 11.0;
      };

      window = {
        hideEdgeBorders = "both";
        border = 0;
      };

      focus = {
        followMouse = "no";
        mouseWarping = false;
      };

      colors = with sol; {
        focused = {
          border = base3;
          background = base3;
          text = base00;
          indicator = base00;
          childBorder = base3;
        };
        unfocused = {
          border = base03;
          background = base03;
          text = base0;
          indicator = base0;
          childBorder = base03;
        };
      };

      keybindings = lib.mkOptionDefault {
        "${mod}+space" = "exec rofi -show drun";
        "${mod}+m" = "exec toggle-mute";
        "${mod}+backslash" = "exec swaylock -c 002b36";
        "${mod}+Shift+space" = ''exec grim -p "$(slurp)" - | wl-copy'';

        "${mod}+ampersand" = "workspace 1";
        "${mod}+bracketleft" = "workspace 2";
        "${mod}+braceleft" = "workspace 3";
        "${mod}+braceright" = "workspace 4";
        "${mod}+parenleft" = "workspace 5";
        "${mod}+equal" = "workspace 6";
        "${mod}+asterisk" = "workspace 7";
        "${mod}+parenright" = "workspace 8";
        "${mod}+plus" = "workspace 9";
        "${mod}+bracketright" = "workspace 10";

        "${mod}+Shift+ampersand" = "move container to workspace 1";
        "${mod}+Shift+bracketleft" = "move container to workspace 2";
        "${mod}+Shift+braceleft" = "move container to workspace 3";
        "${mod}+Shift+braceright" = "move container to workspace 4";
        "${mod}+Shift+parenleft" = "move container to workspace 5";
        "${mod}+Shift+equal" = "move container to workspace 6";
        "${mod}+Shift+asterisk" = "move container to workspace 7";
        "${mod}+Shift+parenright" = "move container to workspace 8";
        "${mod}+Shift+plus" = "move container to workspace 9";
        "${mod}+Shift+bracketright" = "move container to workspace 10";
      };
    };
  };
}
