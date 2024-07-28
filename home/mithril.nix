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

  wayland.windowManager.hyprland = {
    extraConfig = lib.mkBefore ''
      env = LIBVA_DRIVER_NAME,nvidia
      env = GBM_BACKEND,nvidia-drm
      env = __GLX_VENDOR_LIBRARY_NAME,nvidia
      env = WLR_NO_HARDWARE_CURSORS,1

      # No idea why this monitor appears, but disable it :shrug:
      monitor = Unknown-1, disable
    '';
  };

  xdg.configFile = {
    "wireplumber/wireplumber.conf.d/51-config.conf".text = ''
      wireplumber.settings = {
        bluetooth.autoswitch-to-headset-profile = false
      }

      monitor.alsa.rules = [
        # disable all alsa devices except mic
        # disable output on mic
        {
          matches = [
            { device.nick = "!Samson GoMic" }
            { node.nick = "Samson GoMic", media.class = "Audio/Sink" }
          ]
          actions = { update-props = { device.disabled = true } }
        }
      ]
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
