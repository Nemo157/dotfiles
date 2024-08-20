{ lib, pkgs, ... }:
let
  hyprctl = lib.getExe' pkgs.hyprland "hyprctl";
  hypridle = lib.getExe pkgs.hypridle;
  hyprlock = lib.getExe pkgs.hyprlock;

  pidof = lib.getExe' pkgs.procps "pidof";
  pkill = lib.getExe' pkgs.procps "pkill";
  rofi = lib.getExe pkgs.rofi;
  wljoywake = lib.getExe pkgs.wljoywake;

  loginctl = lib.getExe' pkgs.systemd "loginctl";
  systemctl = lib.getExe' pkgs.systemd "systemctl";

  darkenListeners = let
    mkShader = amount: let
      left = 1.0 - amount;
      ratio = lib.min amount (1.0 / 3.0);
      original = toString (left * (1.0 - 2.0 * ratio));
      other = toString (left * ratio);
    in pkgs.writeText "darken-${toString amount}.frag" ''
      precision mediump float;
      varying vec2 v_texcoord;
      uniform sampler2D tex;

      void main() {
          vec4 c = texture2D(tex, v_texcoord);

          vec4 new;

          new[0] = c[0] * ${original} + c[1] * ${other} + c[2] * ${other};
          new[1] = c[0] * ${other} + c[1] * ${original} + c[2] * ${other};
          new[2] = c[0] * ${other} + c[1] * ${other} + c[2] * ${original};
          new[3] = c[3];

          gl_FragColor = new;
      }
    '';

    mkListener = timeout: amount: ''
      listener {
          timeout = ${toString timeout}
          on-timeout = ${hyprctl} keyword decoration:screen_shader ${mkShader amount}
      }
    '';

    startTime = 240;
    endTime = 270;
    duration = endTime - startTime;
    endAmount = 0.7;

    resetListener = ''
      listener {
        timeout = ${toString startTime}
        on-resume = ${hyprctl} keyword decoration:screen_shader ""
      }
    '';

    mkListenerAt = time: mkListener (time + startTime) (endAmount * time / duration);

    listeners = lib.lists.map mkListenerAt (lib.lists.range 0 duration);
  in resetListener + builtins.concatStringsSep "\n" listeners;

in {
  xdg.configFile = {
    "hypr/hypridle.conf" = {
      text = ''
        general {
            lock_cmd = ${pidof} hyprlock || ${hyprlock}
            after_sleep_cmd = ${hyprctl} dispatch dpms on
        }

        ${darkenListeners}

        listener {
            timeout = 300
        }

        listener {
            timeout = 330
            on-timeout = ${hyprctl} dispatch dpms off
            on-resume = ${hyprctl} dispatch dpms on
        }

        listener {
            timeout = 1800
            on-timeout = ${systemctl} suspend
        }
      '';
      onChange = "${systemctl} --user restart hypridle";
    };

    "systemd/user/hypridle.service" = {
      source = "${pkgs.hypridle}/share/systemd/user/hypridle.service";
    };

    "systemd/user/graphical-session.target.wants/hypridle.service" = {
      source = "${pkgs.hypridle}/share/systemd/user/hypridle.service";
    };
  };

  systemd.user.services = {
    wljoywake = {
      Unit = {
        After = "graphical-session.target";
        PartOf = "graphical-session.target";
      };
      Service = {
        ExecStart = "${wljoywake}";
        Restart = "on-failure";
        RestartSteps = 5;
        RestartMaxDelaySec = 10;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
