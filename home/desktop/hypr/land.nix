{ lib, config, pkgs, ... }:
let
  sol = import ../../sol.nix;
in {
  scripts.wl-screenshot = {
    runtimeInputs = [ pkgs.grim pkgs.slurp pkgs.wl-clipboard pkgs.swayimg ];
    text = ''
      # ideas stolen from https://github.com/emersion/slurp/issues/104#issuecomment-1381110649

      grim - | swayimg --scale real --fullscreen - &
      # shellcheck disable=SC2064
      trap "kill $!" EXIT

      sleep 1

      grim -t png -g "$(slurp)" - | wl-copy -t image/png
    '';
  };

  home.packages = with pkgs; [ xwayland ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;

    extraConfig = ''
      env = XDG_SESSION_TYPE,wayland
      env = NIXOS_OZONE_WL,1

      exec-once = systemctl --user import-environment HYPRLAND_INSTANCE_SIGNATURE

      monitor = , highres, auto, 1
      monitor = desc:Samsung Electric Company U32J59x H4LRC00573, highres, auto-up, 1

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
        col.active_border = ${sol.rgb.yellow} ${sol.rgb.orange} ${sol.rgb.red} ${sol.rgb.violet} 45deg
        col.inactive_border = ${sol.rgb.base0} ${sol.rgb.base1} ${sol.rgb.base2} ${sol.rgb.base3} 45deg
        layout = dwindle
      }

      cursor {
        no_hardware_cursors = true
        no_break_fs_vrr = true
        no_warps = true
      }

      misc {
        vrr = 0
        mouse_move_enables_dpms = true
        key_press_enables_dpms = true
        disable_hyprland_logo = true
      }

      render {
        direct_scanout = true
      }

      decoration {
        active_opacity = 0.95
        inactive_opacity = 0.8
      }

      debug {
        disable_logs = false
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
      }

      $mod = ALT

      # these keybindings look odd because they're the qwerty keys that are in
      # the expected dvp positions, e.g. Y is fullscreen because that key is F
      # in dvp
      bind = $mod, SPACE, exec, rofi-systemd
      bind = $mod SHIFT, SPACE, exec, rofi-characters
      bind = $mod, C, togglesplit,
      bind = $mod, COMMA, killactive,
      bind = $mod SHIFT CTRL, D, exec, systemctl --user stop hyprland-session.target
      bind = $mod SHIFT CTRL, D, exit,
      bind = $mod SHIFT, SEMICOLON, exec, wl-screenshot

      bind = SUPER, L, exec, loginctl lock-session
      bind = SUPER, L, exec, sleep 1 && hyprctl dispatch dpms off
      bind = $mod, BACKSLASH, exec, loginctl lock-session
      bind = $mod SHIFT, BACKSLASH, exec, loginctl lock-session
      bind = $mod SHIFT, BACKSLASH, exec, sleep 1 && hyprctl dispatch dpms off
      bind = $mod CTRL, BACKSLASH, exec, systemctl suspend

      bind = $mod, Y, fullscreen, 1
      bind = $mod CTRL, Y, togglefloating,
      bind = $mod SHIFT, Y, fullscreen, 0
      bind = $mod CTRL SHIFT, Y, pin,
      bind = $mod, S, exec, hyprctl setprop active opaque toggle

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

      bindm = SUPER, mouse:272, movewindow

      bindl = , XF86MonBrightnessUp, exec, light -A 5
      bindl = , XF86MonBrightnessDown, exec, light -U 5

      bindl = , XF86KbdBrightnessUp, exec, light -s sysfs/leds/apple::kbd_backlight -A 5
      bindl = , XF86KbdBrightnessDown, exec, light -s sysfs/leds/apple::kbd_backlight -U 5

      bindl = , XF86AudioPlay, exec, playerctl -p mpd play-pause
      bindl = , XF86AudioPause, exec, playerctl -p mpd play-pause

      bindl = , switch:on:Lid Switch, exec, hyprctl keyword monitor "eDP-1, disable"
      bindl = , switch:off:Lid Switch, exec, hyprctl keyword monitor "eDP-1, highres, 0x0, 1"

      # no gaps / border when alone on a workspace
      workspace = w[tv1], gapsout:0, gapsin:0
      workspace = f[1], gapsout:0, gapsin:0
      windowrulev2 = bordersize 0, floating:0, onworkspace:w[tv1]
      windowrulev2 = rounding 0, floating:0, onworkspace:w[tv1]
      windowrulev2 = bordersize 0, floating:0, onworkspace:f[1]
      windowrulev2 = rounding 0, floating:0, onworkspace:f[1]

      windowrulev2 = float,class:RimPy,title:^(?!RimPy)

      windowrulev2 = opaque,title:Picture in picture
      windowrulev2 = float,title:Picture in picture
      windowrulev2 = pin,title:Picture in picture
      windowrulev2 = size 30% 30%,title:Picture in picture
      windowrulev2 = move 70% 70%,title:Picture in picture

      windowrulev2 = tile,class:^RimWorldLinux
      windowrulev2 = tile,class:^Minecraft
      windowrulev2 = tile,class:^Melvor

      windowrulev2 = tile,title:^Vintage Story
      windowrulev2 = opaque,title:^Vintage Story

      windowrulev2 = maximize,class:calibre-gui

      # the title: clause avoids applying to menus, only popup windows
      # (annoyingly they appear unfocused and afaict there is no way to force initial focus)
      windowrulev2 = size 1200 800,class:Geeqie,title:Geeqie,floating:1
      windowrulev2 = center,class:Geeqie,title:Geeqie,floating:1
      windowrulev2 = stayfocused,class:Geeqie,title:Geeqie,floating:1
      windowrulev2 = dimaround,class:Geeqie,title:Geeqie,floating:1

      # Android Emulator, no more specific title available
      windowrulev2 = float,title:^Emulator$
      windowrulev2 = move 100%-w-30 30,title:^Emulator$

      windowrulev2 = float,class:rofinix-build
      windowrulev2 = size 1500 500,class:rofinix-build
      windowrulev2 = center,class:rofinix-build
      windowrulev2 = stayfocused,class:rofinix-build
      windowrulev2 = dimaround,class:rofinix-build

      windowrulev2 = tile,title:^EDDiscovery Version
      windowrulev2 = opaque,title:^EDDiscovery Version

      windowrulev2 = tile,class:^steam$,title:^Steam$

      windowrulev2 = fullscreen,class:^steam_app
      windowrulev2 = opaque,class:^steam_app

      windowrulev2 = tile,class:steam_app_1284210
      windowrulev2 = opaque,class:steam_app_1284210

      windowrulev2 = float,class:^steam$,title:^(?!Steam$).+
      windowrulev2 = size 50% 70%,class:^steam$,title:^(?!Steam$).+
      windowrulev2 = center,class:^steam$,title:^(?!Steam$).+

      windowrulev2 = float,class:xdg-desktop-portal-gtk

      layerrule = dimaround, rofi
    '';
  };

  xdg.dataFile."light-mode.d/hyprland-light.sh" = {
    source = pkgs.writeShellScript "hyprland-light.sh" ''
      ${pkgs.hyprland}/bin/hyprctl keyword general:col.active_border '${sol.rgb.yellow} ${sol.rgb.orange} ${sol.rgb.red} ${sol.rgb.violet} 45deg'
      ${pkgs.hyprland}/bin/hyprctl keyword general:col.inactive_border '${sol.rgb.base0} ${sol.rgb.base1} ${sol.rgb.base2} ${sol.rgb.base3} 45deg'
    '';
  };

  xdg.dataFile."dark-mode.d/hyprland-dark.sh" = {
    source = pkgs.writeShellScript "hyprland-dark.sh" ''
      ${pkgs.hyprland}/bin/hyprctl keyword general:col.active_border '${sol.rgb.magenta} ${sol.rgb.blue} ${sol.rgb.cyan} ${sol.rgb.green} 45deg'
      ${pkgs.hyprland}/bin/hyprctl keyword general:col.inactive_border '${sol.rgb.base03} ${sol.rgb.base02} ${sol.rgb.base01} ${sol.rgb.base00} 45deg'
    '';
  };

  programs.zsh.profileExtra = lib.mkAfter ''
    if [[ ! -v WAYLAND_DISPLAY ]] && [[ ! -v TMUX ]] && [[ "$XDG_VTNR" -eq 1 ]]
    then
      Hyprland
      # while we start stopping the target on the exit shortcut, hyprland doesn't actually wait for
      # it to complete, so do that here
      systemctl --user stop hyprland-session.target
      exit
    fi
  '';
}
