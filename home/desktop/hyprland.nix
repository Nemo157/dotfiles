{ lib, config, pkgs, ... }:
let
  sol = builtins.mapAttrs (name: value: "rgb(${value})") (import ../sol.nix).nohash;
in {
  scripts.wl-screenshot = {
    runtimeInputs = [ pkgs.grim pkgs.slurp pkgs.wl-clipboard ];
    text = ''
      grim -g "$(slurp)" - | wl-copy -t image/png
    '';
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemdIntegration = true;
    recommendedEnvironment = true;

    extraConfig = ''
      monitor = ,highres,auto,1

      input {
        kb_layout = us,us
        # dvp is actually my primary layout, but some apps (mostly games) ignore
        # changing the layout and don't support rebinding from qwerty
        kb_variant = ,dvp
        kb_options = caps:escape,compose:ralt,grp:win_space_toggle
        follow_mouse = 2
      }

      general {
        gaps_in = 0
        gaps_out = 0
        border_size = 1
        resize_on_border = true
        col.active_border = ${sol.yellow} ${sol.orange} ${sol.red} ${sol.violet} 45deg
        col.inactive_border = ${sol.base0} ${sol.base1} ${sol.base2} ${sol.base3} 45deg
        layout = dwindle
        no_cursor_warps = true
      }

      animations {
        enabled = true

        bezier = myBezier, 0.05, 0.9, 0.1, 1.05

        animation = windows, 1, 7, myBezier
        animation = windowsOut, 1, 7, default, popin 80%
        animation = border, 1, 10, default
        animation = borderangle, 1, 8, default
        animation = fade, 1, 7, default
        animation = workspaces, 1, 6, default
      }

      dwindle {
        pseudotile = true
        preserve_split = true
      }

      # these keybindings look odd because they're the qwerty keys that are in
      # the expected dvp positions, e.g. Y is fullscreen because that key is F
      # in dvp
      bind = $mod, SPACE, exec, rofi -show drun
      bind = $mod, C, togglesplit,
      bind = $mod, COMMA, killactive,
      bind = $mod, Y, fullscreen, 1
      bind = $mod CTRL, Y, togglefloating,
      bind = $mod SHIFT, Y, fullscreen, 0
      bind = $mod SHIFT CTRL, D, exit,
      bind = $mod SHIFT, COLON, exec, wl-screenshot

      bind = $mod, J, movefocus, l
      bind = $mod, P, movefocus, r
      bind = $mod, C, movefocus, d
      bind = $mod, V, movefocus, u

      bind = $mod SHIFT, J, movewindow, l
      bind = $mod SHIFT, P, movewindow, r
      bind = $mod SHIFT, C, movewindow, d
      bind = $mod SHIFT, V, movewindow, u

      bind = $mod, 1, workspace, 1
      bind = $mod, 2, workspace, 2
      bind = $mod, 3, workspace, 3
      bind = $mod, 4, workspace, 4

      bind = $mod SHIFT, 1, movetoworkspacesilent, 1
      bind = $mod SHIFT, 2, movetoworkspacesilent, 2
      bind = $mod SHIFT, 3, movetoworkspacesilent, 3
      bind = $mod SHIFT, 4, movetoworkspacesilent, 4

      bind = $mod, TAB, workspace, e+1
      bind = $mod SHIFT, TAB, workspace, e-1

      bindm = $mod, mouse:272, movewindow

      bind = , XF86MonBrightnessUp, exec, light -A 5
      bind = , XF86MonBrightnessDown, exec, light -U 5

      bind = , XF86KbdBrightnessUp, exec, light -s sysfs/leds/apple::kbd_backlight -A 5
      bind = , XF86KbdBrightnessDown, exec, light -s sysfs/leds/apple::kbd_backlight -U 5
    '';
  };

  xdg.dataFile."light-mode.d/hyprland-light.sh" = {
    source = pkgs.writeShellScript "hyprland-light.sh" ''
      ${pkgs.hyprland}/bin/hyprctl keyword general:col.active_border '${sol.yellow} ${sol.orange} ${sol.red} ${sol.violet} 45deg'
      ${pkgs.hyprland}/bin/hyprctl keyword general:col.inactive_border '${sol.base0} ${sol.base1} ${sol.base2} ${sol.base3} 45deg'
    '';
  };

  xdg.dataFile."dark-mode.d/hyprland-dark.sh" = {
    source = pkgs.writeShellScript "hyprland-dark.sh" ''
      ${pkgs.hyprland}/bin/hyprctl keyword general:col.active_border '${sol.magenta} ${sol.blue} ${sol.cyan} ${sol.green} 45deg'
      ${pkgs.hyprland}/bin/hyprctl keyword general:col.inactive_border '${sol.base03} ${sol.base02} ${sol.base01} ${sol.base00} 45deg'
    '';
  };
}
