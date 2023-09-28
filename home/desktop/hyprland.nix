{ lib, config, pkgs, ... }:
let
  sol = (import ../sol.nix);
in {
  wayland.windowManager.hyprland = {
    enable = true;
    nvidiaPatches = true;
    systemdIntegration = true;
    recommendedEnvironment = true;

    extraConfig = ''
      $mod = ALT

      env = LIBVA_DRIVER_NAME,nvidia
      env = XDG_SESSION_TYPE,wayland
      env = GBM_BACKEND,nvidia-drm
      env = __GLX_VENDOR_LIBRARY_NAME,nvidia
      env = WLR_NO_HARDWARE_CURSORS,1

      monitor = ,highres,auto,1

      input {
        kb_layout = us
        kb_variant = dvp
        follow_mouse = 2
      }

      general {
        gaps_in = 0
        gaps_out = 0
        border_size = 1
        resize_on_border = true
        col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
        col.inactive_border = rgba(595959aa)
        layout = dwindle;
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

      bind = $mod, SPACE, exec, rofi -show drun
      bind = $mod, P, pseudo,
      bind = $mod, J, togglesplit,
      bind = $mod SHIFT CTRL, E, exit,

      bind = $mod, H, movefocus, l
      bind = $mod, L, movefocus, r
      bind = $mod, J, movefocus, d
      bind = $mod, K, movefocus, u

      bind = $mod SHIFT, H, movewindow, l
      bind = $mod SHIFT, L, movewindow, r
      bind = $mod SHIFT, J, movewindow, d
      bind = $mod SHIFT, K, movewindow, u

      bind = $mod, ampersand, workspace, 1
      bind = $mod, bracketleft, workspace, 2
      bind = $mod, braceleft, workspace, 3
      bind = $mod, braceright, workspace, 4

      bind = $mod SHIFT, ampersand, movetoworkspacesilent, 1
      bind = $mod SHIFT, bracketleft, movetoworkspacesilent, 2
      bind = $mod SHIFT, braceleft, movetoworkspacesilent, 3
      bind = $mod SHIFT, braceright, movetoworkspacesilent, 4

      bind = $mod, tab, workspace, +1
      bind = $mod SHIFT, tab, workspace, -1

      windowrule = noborder, Conky
      windowrule = float, Conky
      windowrule = pin, Conky
    '';
  };
}
