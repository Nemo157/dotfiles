{ lib, config, pkgs, ... }: {
  imports = [
    ./cli
    ./dev
    ./chill
    ./chill-server
    ./desktop
    ./xdg.nix
    ./age.nix
    ./personal
  ];

  home.stateVersion = "23.05";

  programs.home-manager.enable = true;

  systemd.user.startServices = "sd-switch";

  home.packages = with pkgs; [
    stc-cli
    flatpak
  ];

  services.syncthing = {
    enable = true;
    tray.enable = true;
  };

  xdg.configFile = {
    "wireplumber/wireplumber.conf.d/51-config.conf".text = ''
      monitor.alsa.rules = [
        # disable all alsa devices except mic
        # disable output on mic
        {
          matches = [
            { device.nick = "!~(Samson GoMic|HDA NVidia)" }
            { node.nick = "Samson GoMic", media.class = "Audio/Sink" }
          ]
          actions = { update-props = { device.disabled = true } }
        }
      ]

      monitor.bluez.rules = [
        {
          matches = [
            { device.description = "WH-1000XM3" }
          ]
          actions = {
            update-props = {
              media-role.use-headset-profile = false
              bluetooth.autoswitch-to-headset-profile = false
              bluez5.autoswitch-profile = false

              bluez5.auto-connect = [ a2dp_sink ]
            }
          }
        }
      ]

      monitor.bluez.properties = {
        bluez5.roles = [ a2dp_source a2dp_sink ]
        bluez5.hfphsp-backend = "none"
      }
    '';

    "pipewire/pipewire.conf.d/92-low-latency.conf".text = ''
      context.properties = {
        default.clock.rate = 48000
        default.clock.quantum = 256
        default.clock.min-quantum = 256
        default.clock.max-quantum = 256
      }
    '';
  };

  scripts."switch-to-virtual-monitor" = {
    runtimeInputs = with pkgs; [ hyprland eww systemd ];
    text = ''
        hyprctl output create headless
        hyprctl keyword monitor HEADLESS-2,2560x1600@60,0x0,1
        hyprctl keyword monitor HDMI-A-1,1920x1080,0x0,1
        hyprctl keyword monitor HDMI-A-1,disable
        eww close-all
        eww open taskbar
    '';
  };
}
