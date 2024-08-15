{ config, nixos-hardware, pkgs, ... }: {
  imports = [
    ../client
    ../laptop

    nixos-hardware.common-cpu-intel
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
      "i2c"
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
    bluetooth.enable = true;
  };

  boot.kernelParams = [ "i915.force_probe=7d55" ];

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    storageDriver = "overlay2";
  };

  # Can't use extraRules because this needs to go before 73 for uaccess support
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "stlink-udev-rules";
      text = ''
        # ID 0483:374e STMicroelectronics STLINK-V3
        SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="0483", ENV{ID_MODEL_ID}=="374e", TAG+="uaccess", MODE="660"
        # ID 0483:374d STMicroelectronics STLINK-V3 Loader
        SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="0483", ENV{ID_MODEL_ID}=="374d", TAG+="uaccess", MODE="660"
      '';
      destination = "/etc/udev/rules.d/70-stlink.rules";
    })
  ];
}
