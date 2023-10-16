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
    nvidiaPatches = true;
    extraConfig = lib.mkBefore ''
      env = LIBVA_DRIVER_NAME,nvidia
      env = XDG_SESSION_TYPE,wayland
      env = GBM_BACKEND,nvidia-drm
      env = __GLX_VENDOR_LIBRARY_NAME,nvidia
      env = WLR_NO_HARDWARE_CURSORS,1
    '';
  };
}
