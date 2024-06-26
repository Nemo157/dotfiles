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
    '';
  };

  xdg.configFile = {
    "wireplumber/main.lua.d/51-alsa-config.lua".text = ''
      table.insert(alsa_monitor.rules, {
        matches = {
          {
            { "device.nick", "is-present" },
            { "device.nick", "not-equals", "Samson GoMic" },
          },
        },
        apply_properties = {
          -- disable all alsa devices except mic
          ["device.disabled"] = true,
        },
      })

      -- table.insert(alsa_monitor.rules, {
      --   matches = {
      --     {
      --       { "node.nick", "equals", "Samson GoMic" },
      --       { "media.class", "equals", "Audio/Sink" },
      --     },
      --   },
      --   apply_properties = {
      --     -- disable output on mic
      --     ["node.disabled"] = true,
      --   },
      -- })
    '';

    "wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
      table.insert(bluez_monitor.rules, {
        matches = {
          { { "device.description", "equals", "WH-1000XM3" } },
        },
        apply_properties = {
          -- only use as an output
          ["bluez5.auto-connect"] = "[ a2dp_sink ]",
        },
      })
      table.insert(bluez_monitor.rules, {
        matches = {
          { { "node.description", "equals", "WH-1000XM3" } },
        },
        apply_properties = {
          -- ensure bluetooth headset is picked as default
          ["priority.session"] = 1200,
        },
      })
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
        hyprctl keyword monitor Unknown-1,disable
        hyprctl keyword monitor HDMI-A-1,disable
        eww close-all
        eww open taskbar
    '';
  };
}
