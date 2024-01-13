{ lib, config, pkgs, ... }:
let
  sol = builtins.mapAttrs (name: value: "rgb(${value})") (import ../sol.nix).nohash;
in {
  scripts.wl-screenshot = {
    runtimeInputs = [ pkgs.grim pkgs.slurp pkgs.wl-clipboard pkgs.swayimg ];
    text = ''
      # ideas stolen from https://github.com/emersion/slurp/issues/104#issuecomment-1381110649

      grim - | swayimg --background none --scale real --no-sway --fullscreen --layer - &
      # shellcheck disable=SC2064
      trap "kill $!" EXIT
      grim -t png -g "$(slurp)" - | wl-copy -t image/png
    '';
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;

    extraConfig = ''
      monitor = ,highres,auto,1

      input {
        kb_layout = us,us
        # dvp is actually my primary layout, but some apps (mostly games) ignore
        # changing the layout and don't support rebinding from qwerty
        kb_variant = ,dvp
        kb_options = caps:escape,compose:ralt,grp:win_space_toggle
        follow_mouse = 2

        touchpad {
          natural_scroll = true
          clickfinger_behavior = true
          tap-and-drag = true
        }
      }

      gestures {
        workspace_swipe = true
        workspace_swipe_fingers = 4
        workspace_swipe_cancel_ratio = 0.3
      }

      general {
        gaps_in = 10
        gaps_out = 20
        border_size = 0
        resize_on_border = true
        col.active_border = ${sol.yellow} ${sol.orange} ${sol.red} ${sol.violet} 45deg
        col.inactive_border = ${sol.base0} ${sol.base1} ${sol.base2} ${sol.base3} 45deg
        layout = dwindle
        no_cursor_warps = true
      }

      decoration {
        active_opacity = 0.95
        inactive_opacity = 0.8
      }

      debug {
        # disable_logs = false
      }

      animations {
        enabled = true

        bezier = sine, 0.37, 0.0, 0.63, 1
        bezier = cubic, 0.65, 0.0, 0.35, 1
        bezier = circ, 0.85, 0.0, 0.15, 1

        animation = global, 1, 5, cubic
        animation = workspaces, 1, 7, cubic, slidefade 200%
      }

      dwindle {
        pseudotile = true
        preserve_split = true
        no_gaps_when_only = 1
      }

      $mod = ALT

      # these keybindings look odd because they're the qwerty keys that are in
      # the expected dvp positions, e.g. Y is fullscreen because that key is F
      # in dvp
      bind = $mod, SPACE, exec, rofi -show drun
      bind = $mod, C, togglesplit,
      bind = $mod, COMMA, killactive,
      bind = $mod SHIFT CTRL, D, exit,
      bind = $mod SHIFT, SEMICOLON, exec, wl-screenshot

      bind = $mod, Y, fullscreen, 1
      bind = $mod CTRL, Y, togglefloating,
      bind = $mod SHIFT, Y, fullscreen, 0
      bind = $mod CTRL SHIFT, Y, pin,
      bind = $mod, S, toggleopaque,

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
      bind = $mod, 5, workspace, 5

      bind = $mod SHIFT, 1, movetoworkspacesilent, 1
      bind = $mod SHIFT, 2, movetoworkspacesilent, 2
      bind = $mod SHIFT, 3, movetoworkspacesilent, 3
      bind = $mod SHIFT, 4, movetoworkspacesilent, 4
      bind = $mod SHIFT, 5, movetoworkspacesilent, 5

      bind = $mod, TAB, workspace, e+1
      bind = $mod SHIFT, TAB, workspace, e-1

      bindm = $mod, mouse:272, movewindow

      bind = , XF86MonBrightnessUp, exec, light -A 5
      bind = , XF86MonBrightnessDown, exec, light -U 5

      bind = , XF86KbdBrightnessUp, exec, light -s sysfs/leds/apple::kbd_backlight -A 5
      bind = , XF86KbdBrightnessDown, exec, light -s sysfs/leds/apple::kbd_backlight -U 5

      windowrulev2 = float,class:RimPy,title:^(?!RimPy)

      windowrulev2 = opaque,title:Picture in picture
      windowrulev2 = float,title:Picture in picture
      windowrulev2 = pin,title:Picture in picture
      windowrulev2 = size 576 324,title:Picture in picture
      windowrulev2 = move 100%-577 100%-325,title:Picture in picture

      windowrulev2 = tile,class:^RimWorldLinux
      windowrulev2 = tile,class:^Minecraft
      windowrulev2 = tile,class:^Melvor

      windowrulev2 = tile,title:^Vintage Story
      windowrulev2 = opaque,title:^Vintage Story

      windowrulev2 = maximize,class:calibre-gui

      windowrulev2 = tile,class:steam_app_1284210
      windowrulev2 = opaque,class:steam_app_1284210
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

  programs.zsh.profileExtra = ''
    if [[ -z "$WAYLAND_DISPLAY" ]] && [[ "$XDG_VTNR" -eq 1 ]]
    then
      exec Hyprland
    fi
  '';
}
