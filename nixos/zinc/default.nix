{ config, pkgs, ts, ... }:

{
  imports = [
    ./hardware
    ./users.nix
    ./boot-loader.nix
    ./networking.nix
    ./services
    ../autologin.nix
  ];

  nix = {
    package = pkgs.nixFlakes;
    settings = {
      builders-use-substitutes = true;
      experimental-features = "nix-command flakes";
      substituters = [
        "http://${ts.hosts.mithril.host}:5069"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "mithril-1:3qkcEGevkLvRmGmNMqXJUQ/mXvs9MPudk5ugxUf7orM="
      ];
    };
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "${ts.hosts.mithril.host}";
        system = "x86_64-linux";
        sshUser = "nix-ssh";
        protocol = "ssh-ng";
        maxJobs = 20;
        supportedFeatures = [
          "kvm"
          "nixos-test"
          "big-parallel"
        ];
      }
    ];
  };

  system.stateVersion = "23.05";

  time.timeZone = "Europe/Berlin";

  console.keyMap = "dvorak-programmer";

  security.polkit.enable = true;

  programs = {
    zsh.enable = true;
    light.enable = true;
    yubikey-touch-detector.enable = true;
  };

  age = {
    identityPaths = [ "/home/nemo157/.ssh/id_ed25519-agenix" ];
  };

  boot.tmp.cleanOnBoot = true;
}
