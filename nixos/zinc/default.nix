{ nixos-hardware, config, pkgs, ts, ... }: {
  imports = [
    ../client
    ../laptop
    ../personal

    nixos-hardware.apple-t2
    nixos-hardware.common-cpu-intel
    nixos-hardware.common-pc-laptop
    nixos-hardware.common-pc-ssd

    ./hardware
    ./boot-loader.nix
    ./networking.nix
    ./services
  ];

  system.stateVersion = "23.05";

  nix = {
    settings = {
      builders-use-substitutes = true;
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

  hardware.bluetooth.enable = true;
}
