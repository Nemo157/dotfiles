{ lib, config, pkgs, ... }: {
  imports = [
    ./cli
    ./chill
    ./chill-server
    ./desktop
    ./xdg.nix
  ];

  home.stateVersion = "23.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    stc-cli
    flatpak
  ];

  services.syncthing = {
    enable = true;
    tray.enable = true;
  };

  age = {
    identityPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519-agenix" ];
    # Needs to have $XDG_RUNTIME_DIR pre-resolved
    secretsDir = "/run/user/1000/agenix";
  };

  wayland.windowManager.hyprland = {
    enableNvidiaPatches = true;
    extraConfig = lib.mkBefore ''
      env = LIBVA_DRIVER_NAME,nvidia
      env = XDG_SESSION_TYPE,wayland
      env = GBM_BACKEND,nvidia-drm
      env = __GLX_VENDOR_LIBRARY_NAME,nvidia
      env = WLR_NO_HARDWARE_CURSORS,1
    '';
  };

  xdg.configFile."wireplumber/main.lua.d/51-alsa-config.lua".text = ''
    table.insert(alsa_monitor.rules, {
      matches = {
        {
          { "device.nick", "is-present" },
          { "device.nick", "not-equals", "Samson Go Mic" },
        },
      },
      apply_properties = {
        -- disable all alsa devices except mic
        ["device.disabled"] = true,
      },
    })

    table.insert(alsa_monitor.rules, {
      matches = {
        {
          { "node.nick", "equals", "Samson Go Mic" },
          { "media.class", "equals", "Audio/Sink" },
        },
      },
      apply_properties = {
        -- disable output on mic
        ["node.disabled"] = true,
      },
    })
  '';

  xdg.configFile."wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
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
}
