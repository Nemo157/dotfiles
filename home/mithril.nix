{ lib, config, pkgs, ... }: {
  imports = [
    ./cli
    ./desktop
    ./chill
  ];

  home.stateVersion = "23.05";

  programs.home-manager.enable = true;

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
  ];

  home.packages = [
    pkgs.stc-cli
  ];

  xdg.userDirs = {
    enable = true;
    music = "${config.home.homeDirectory}/Music/Library";
  };

  services.syncthing = {
    enable = true;
    tray.enable = true;
  };

  age = {
    identityPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519-agenix" ];
    # Needs to have $XDG_RUNTIME_DIR pre-resolved
    secretsDir = "/run/user/1000/agenix";
  };
}
