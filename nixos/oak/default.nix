{ config, nixos-hardware, pkgs, ... }: {
  imports = [
    ../client
    ../laptop

    nixos-hardware.common-gpu-intel
    nixos-hardware.common-gpu-intel
    nixos-hardware.common-pc-laptop
    nixos-hardware.common-pc-ssd

    ./hardware-configuration.nix
    ./boot-loader.nix
    ./networking.nix
    ./telegraf-grafana.nix
  ];

  system.stateVersion = "24.05";

  users.users.wim = {
    isNormalUser = true;
    hashedPassword = "$y$j9T$E6IJdj3Qsa1ZUpR4fTNP..$WE5sYB3PmotlsD.IRz6kNuIyWYG4VOLa3yosbVnPNk/";
    extraGroups = [
      "docker"
      "input"
      "networkmanager"
      "seat"
      "tty"
      "users"
      "video"
      "wheel"
      "wireshark"
      "kvm"
    ];
    shell = pkgs.zsh;
  };

  main-user = "wim";

  hardware.enableRedistributableFirmware = true;

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
  };

  boot.kernelParams = [ "i915.force_probe=7d55" ];
}
