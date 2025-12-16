{ lib, pkgs, ... }: let
  configFile = pkgs.writeTextFile {
    name = "niri-config.kdl";

    checkPhase = ''
      ${lib.getExe pkgs.niri} validate --config "$target"
    '';

    text = ''
      // https://yalter.github.io/niri/Configuration:-Introduction

      input {
          keyboard {
              xkb {
                  layout "us,us"
                  variant ",dvp"
                  options "caps:escape,compose:ralt,grp:win_space_toggle"
              }

              numlock
          }

          touchpad {
              tap
              natural-scroll
          }
      }

      output "PNP(AOC) U27G3X ZXKQ4HA005438" {
          scale 1
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
          match app-id="^steam_app_(1977170)$"
          open-fullscreen true
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
          match is-floating=true
          focus-ring {
              on
          }
      }

      layer-rule {
        match namespace="^swww-daemon$"
        place-within-backdrop true
      }

      layout {

        gaps 0
        struts { top 0; bottom 0; left 0; right 64; }

        empty-workspace-above-first
        default-column-width { proportion 1.0; }
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
          Alt+Shift+Z { show-hotkey-overlay; }

          Alt+Space hotkey-overlay-title="Run an Application: rofi" { spawn "rofi-systemd"; }
          Alt+BackSlash hotkey-overlay-title="Lock the Session" { spawn "loginctl" "lock-session"; }

          Alt+O repeat=false { toggle-window-rule-opacity; }

          Alt+W repeat=false { close-window; }

          Alt+H { focus-column-left; }
          Alt+J { focus-window-down; }
          Alt+K { focus-window-up; }
          Alt+L { focus-column-right; }

          Alt+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
          Alt+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }
          Alt+WheelScrollRight cooldown-ms=150 { focus-column-right; }
          Alt+WheelScrollLeft cooldown-ms=150 { focus-column-left; }

          Alt+Shift+H { consume-or-expel-window-left; }
          Alt+Shift+J { move-window-down; }
          Alt+Shift+K { move-window-up; }
          Alt+Shift+L { consume-or-expel-window-right; }

          Alt+Ampersand { focus-workspace 1; }
          Alt+BracketLeft { focus-workspace 2; }
          Alt+BraceLeft { focus-workspace 3; }
          Alt+BraceRight { focus-workspace 4; }
          Alt+ParenLeft { focus-workspace 5; }

          Alt+Shift+Ampersand { move-column-to-workspace 1; }
          Alt+Shift+BracketLeft { move-column-to-workspace 2; }
          Alt+Shift+BraceLeft { move-column-to-workspace 3; }
          Alt+Shift+BraceRight { move-column-to-workspace 4; }
          Alt+Shift+ParenLeft { move-column-to-workspace 5; }

          Alt+R { switch-preset-column-width; }

          Alt+F { maximize-column; }
          Alt+Shift+F { fullscreen-window; }
          Alt+Ctrl+F { toggle-window-floating; }

          Alt+S { screenshot; }
          Alt+Shift+S { screenshot-screen; }
          Alt+Ctrl+S { screenshot-window; }

          Alt+Ctrl+Shift+E { quit; }
      }
    '';
  };
in {
  home.packages = [ pkgs.niri ];

  xdg.configFile."niri/config.kdl".source = configFile;
}
