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
      randomizedDelaySec = "45min";
    };

    optimise = {
      automatic = true;
    };
  };

  # stable random offset (derived from machine-id + unit name) instead of a
  # fresh roll every boot; systemd >= 247
  systemd.timers.nix-gc.timerConfig.FixedRandomDelay = true;

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
