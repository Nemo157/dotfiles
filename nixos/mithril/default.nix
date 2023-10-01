{ pkgs, ... }: {
  imports = [
    ./boot-loader.nix
    ./hardware
    ./networking.nix
    ./services
    ./users.nix
  ];

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  system.stateVersion = "23.05";

  time.timeZone = "Europe/Berlin";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "dvorak-programmer";
  };

  security.polkit.enable = true;

  environment.systemPackages = with pkgs; [
    vim
  ];

  programs = {
    zsh.enable = true;
    dconf.enable = true;
  };
}
