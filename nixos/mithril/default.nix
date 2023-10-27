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

    settings.trusted-users = [ "root" "nix-ssh" ];

    sshServe = {
      enable = true;
      protocol = "ssh-ng";
      write = true;
      keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMUC6EkpEc8giBYKiu10wfTDFmp2Q2tEIDghN4GO4TZm zinc"
      ];
    };
  };

  system.stateVersion = "23.05";

  time.timeZone = "Europe/Berlin";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "dvorak-programmer";
  };

  security = {
    polkit.enable = true;
    rtkit.enable = true;
  };

  environment.systemPackages = with pkgs; [
    vim
  ];

  programs = {
    zsh.enable = true;
    dconf.enable = true;
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    storageDriver = "zfs";
  };
}
