{ lib, pkgs, ... }: {
  programs.niri = {
    enable = true;

    config = ''
      // https://yalter.github.io/niri/Configuration:-Introduction

      input {
          keyboard {
              xkb {
                  layout "us,us"
                  variant ",dvp"
                  options "caps:escape,compose:ralt,grp:rctrl_rshift_toggle"
              }

              numlock
          }

          touchpad {
              tap
              natural-scroll
          }
      }

      hotkey-overlay {
          skip-at-startup
      }

      prefer-no-csd

      screenshot-path null

      window-rule {
          opacity 0.95
          draw-border-with-background false
      }

      window-rule {
          match is-active=false
          opacity 0.8
      }

      window-rule {
        match app-id="FreeTube"
        opacity 1.0
      }

      window-rule {
        match app-id="^Minecraft"
        opacity 1.0
        open-maximized-to-edges true
      }

      window-rule {
          match app-id="^$" title="^Picture in picture$"
          match app-id="firefox$" title="^Picture-in-Picture$"
          open-floating true
          open-focused false
          opacity 1.0
          default-column-width { fixed 1280; }
          default-window-height { fixed 720; }
          default-floating-position x=10 y=10 relative-to="bottom-right"
      }

      window-rule {
          match app-id="steam" title=r#"^notificationtoasts_\d+_desktop$"#
          default-floating-position x=10 y=10 relative-to="bottom-right"
          opacity 1.0
      }

      window-rule {
          match app-id="steam" title="^Payment Authentication$"
          open-floating true
      }

      window-rule {
        match app-id="calibre-gui"
        open-floating false
        default-column-width { proportion 0.5; }
      }

      window-rule {
        match app-id="calibre-gui" title="^calibre"
        default-column-width { proportion 0.66667; }
      }

      window-rule {
          match is-floating=true
          focus-ring {
              on
          }
      }

      window-rule {
          match is-window-cast-target=true
          border {
              on
              width 4
              active-gradient from="#dc322f" to="#cb4b16" angle=45
              inactive-gradient from="#dc322f" to="#cb4b16" angle=45
          }
      }

      window-rule {
          match app-id="^steam_app_.*"
          open-fullscreen true
      }

      layer-rule {
        match namespace="^awww-daemon$"
        place-within-backdrop true
      }

      layout {

        gaps 0
        struts { top 0; bottom 0; left 0; right 64; }

        empty-workspace-above-first

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
            proportion 1.0
        }

        default-column-width { proportion 0.66667; }

        background-color "transparent"
        focus-ring {
          off
          active-gradient from="#cb4b16" to="#859900" angle=45 relative-to="workspace-view"
        }

        border { off; }
        shadow { off; }
        insert-hint {
            gradient from="#2aa19880" to="#cb4b1680" angle=45 relative-to="workspace-view"
        }
      }

      overview {
        workspace-shadow {
          off
        }
      }

      xwayland-satellite {
        path "${lib.getExe pkgs.xwayland-satellite}"
      }

      environment {
        XDG_SESSION_TYPE "wayland"
        NIXOS_OZONE_WL "1"
      }

      clipboard {
        disable-primary
      }

      binds {
          Mod+Shift+Slash { show-hotkey-overlay; }

          Mod+Space hotkey-overlay-title="Run an Application: rofi" { spawn "rofi-systemd"; }
          Mod+BackSlash hotkey-overlay-title="Lock the Session" { spawn "loginctl" "lock-session"; }

          XF86AudioPlay { spawn "playerctl" "play"; }
          XF86AudioPause { spawn "playerctl" "pause"; }
          XF86AudioNext { spawn "playerctl" "next"; }
          XF86AudioPrev { spawn "playerctl" "previous"; }

          Mod+O repeat=false { toggle-window-rule-opacity; }

          Mod+W repeat=false { close-window; }

          Mod+H { focus-column-left; }
          Mod+J { focus-window-or-workspace-down; }
          Mod+K { focus-window-or-workspace-up; }
          Mod+L { focus-column-right; }

          Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
          Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }
          Mod+WheelScrollRight cooldown-ms=150 { focus-column-right; }
          Mod+WheelScrollLeft cooldown-ms=150 { focus-column-left; }

          Mod+Shift+H { consume-or-expel-window-left; }
          Mod+Shift+J { move-window-down-or-to-workspace-down; }
          Mod+Shift+K { move-window-up-or-to-workspace-up; }
          Mod+Shift+L { consume-or-expel-window-right; }

          Mod+Ampersand { focus-workspace 1; }
          Mod+BracketLeft { focus-workspace 2; }
          Mod+BraceLeft { focus-workspace 3; }
          Mod+BraceRight { focus-workspace 4; }
          Mod+ParenLeft { focus-workspace 5; }

          Mod+Shift+Ampersand { move-column-to-workspace 1; }
          Mod+Shift+BracketLeft { move-column-to-workspace 2; }
          Mod+Shift+BraceLeft { move-column-to-workspace 3; }
          Mod+Shift+BraceRight { move-column-to-workspace 4; }
          Mod+Shift+ParenLeft { move-column-to-workspace 5; }

          Mod+R { switch-preset-column-width; }

          Mod+F { maximize-window-to-edges; }
          Mod+Shift+F { fullscreen-window; }
          Mod+Shift+Ctrl+F { toggle-windowed-fullscreen; }
          Mod+Ctrl+F { toggle-window-floating; }

          Mod+S { screenshot; }
          Mod+Shift+S { screenshot-screen; }
          Mod+Ctrl+S { screenshot-window; }

          Mod+P hotkey-overlay-title="Dynamic Cast: Window" { set-dynamic-cast-window; }
          Mod+Shift+P hotkey-overlay-title="Dynamic Cast: Monitor" { set-dynamic-cast-monitor; }
          Mod+Ctrl+P hotkey-overlay-title="Dynamic Cast: Clear" { clear-dynamic-cast-target; }

          Mod+Ctrl+Shift+E { quit; }
      }
    '';
  };

  programs = {
    swaylock = {
      enable = true;
    };
  };

  services = {
    swayidle = {
      enable = true;
      events = {
        lock = "${lib.getExe pkgs.swaylock} -fF";
      };
    };
  };

  programs.zsh.profileExtra = lib.mkAfter ''
    if [[ ! -v WAYLAND_DISPLAY ]] && [[ ! -v TMUX ]] && [[ "$XDG_VTNR" -eq 1 ]]
    then
      exec niri-session
    fi
  '';
}
