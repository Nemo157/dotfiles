{ config, pkgs, ... }: {
  imports = [
    ./services
    ./network.nix
  ];

  nix = {
    daemonIOSchedClass = "idle";
    daemonCPUSchedPolicy = "idle";

    settings = {
      experimental-features = "nix-command flakes";
      download-buffer-size = 524288000;
    };

    gc = {
      automatic = true;
    };

    optimise = {
      automatic = true;
    };
  };

  systemd.services.nix-gen-gc = {
    description = "NixOS Generation Garbage Collector";
    script = "exec ${config.nix.package.out}/bin/nix-env -vvvv --profile /nix/var/nix/profiles/system --delete-generations +10";
    wantedBy = ["nix-gc.service"];
    serviceConfig.Type = "oneshot";
  };

  environment.systemPackages = with pkgs; [
    vim
    man-pages
    man-pages-posix
  ];

  fonts.packages = with pkgs; [
    liberation_ttf
  ];
}
