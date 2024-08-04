{ pkgs, ... }: {
  home.packages = with pkgs; [ hypridle rofi ];

  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        lock_cmd = pidof hyprlock || hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
    }

    listener {
        timeout = 270
        on-timeout = rofi -e 'locking in 30s' -theme-str 'textbox { horizontal-align: 0.5; }'
        on-resume = pkill -e -s0 rofi
    }

    listener {
        timeout = 300
        on-timeout = loginctl lock-session
    }

    listener {
        timeout = 330
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
    }

    listener {
        timeout = 1800
        on-timeout = systemctl suspend
    }
  '';
}
