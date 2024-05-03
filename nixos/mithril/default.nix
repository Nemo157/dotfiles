{ pkgs, ... }: {
  imports = [
    ./boot-loader.nix
    ./hardware
    ./networking.nix
    ./services
    ./users.nix
    ../autologin.nix
  ];

  nix = {
    settings.trusted-users = [ "root" "nix-ssh" ];

    daemonIOSchedClass = "idle";
    daemonCPUSchedPolicy = "idle";

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
  system.nixos.distroName = "i use arch, btw";

  time.timeZone = "Europe/Berlin";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "dvorak-programmer";
  };

  security = {
    polkit.enable = true;
    rtkit.enable = true;
    pam.u2f.enable = true;
  };

  environment.systemPackages = with pkgs; [
    vim
    man-pages
    man-pages-posix
  ];

  programs = {
    zsh.enable = true;
    dconf.enable = true;
    wireshark.enable = true;
    yubikey-touch-detector.enable = true;
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    storageDriver = "zfs";
  };

  systemd.coredump.extraConfig = ''
    ProcessSizeMax = 1G
    ExternalSizeMax = 1G
  '';

  documentation.dev.enable = true;

  boot.tmp.cleanOnBoot = true;
}
