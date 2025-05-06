{ nixos-hardware, pkgs, ... }: {
  imports = [
    ../client
    ../desktop
    ../personal

    nixos-hardware.common-cpu-amd
    nixos-hardware.common-gpu-amd
    nixos-hardware.common-pc-ssd

    ./boot-loader.nix
    ./hardware
    ./networking.nix
    ./services
  ];

  system.stateVersion = "23.05";

  nix = {
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

  time.timeZone = "Europe/Berlin";

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    storageDriver = "zfs";
  };
}
