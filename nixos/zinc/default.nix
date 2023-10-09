{ config, pkgs, ... }:

{
  imports = [
    ./hardware
    ./users.nix
    ./boot-loader.nix
    ./networking.nix
    ./services
  ];

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "mithril";
        system = "x86_64-linux";
        sshUser = "nix-ssh";
        protocol = "ssh-ng";
        maxJobs = 20;
      }
    ];
  };

  system.stateVersion = "23.05";

  time.timeZone = "Europe/Berlin";

  console.keyMap = "dvorak-programmer";

  security.polkit.enable = true;

  programs.zsh.enable = true;

  age = {
    identityPaths = [ "/home/nemo157/.ssh/id_ed25519-agenix" ];
  };

}