{ lib, pkgs, ... }: {
  home.packages = [ pkgs.niri ];

  xdg.configFile."niri/config.kdl"= {
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
          match app-id=r#"firefox$"# title="^Picture-in-Picture$"
          open-floating true
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

          Alt+O repeat=false { toggle-overview; }

          Alt+W repeat=false { close-window; }

          Alt+H { focus-column-left; }
          Alt+J { focus-window-down; }
          Alt+K { focus-window-up; }
          Alt+L { focus-column-right; }

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
}
