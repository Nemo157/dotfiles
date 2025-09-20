{ pkgs, ... }: {
  imports = [
    ./autologin.nix
    ./monitors.nix
    ./services
  ];

  system.nixos.distroName = "i use arch, btw";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "dvorak-programmer";
  };

  security = {
    polkit.enable = true;
    rtkit.enable = true;
    pam = {
      u2f.enable = true;
      services.hyprlock = {
        # hyprlock has issues with parallel u2f and password,
        # disable u2f for now
        u2fAuth = false;
      };
    };
  };

  programs = {
    dconf.enable = true;
    wireshark.enable = true;
    zsh.enable = true;
  };

  boot.tmp.cleanOnBoot = true;

  systemd.coredump.extraConfig = ''
    ProcessSizeMax = 1G
    ExternalSizeMax = 1G
  '';

  documentation.dev.enable = true;

  # Can't use extraRules because this needs to go before 73 for uaccess support
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "rpi-pico-udev-rules";
      text = ''
        # ID 2e8a:000a Raspberry Pi Pico
        SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="2e8a", ENV{ID_MODEL_ID}=="000a", TAG+="uaccess", MODE="660"
      '';
      destination = "/etc/udev/rules.d/70-rpi-pico.rules";
    })
    (pkgs.writeTextFile {
      name = "ἐννεάς-udev-rules";
      text = ''
        # ID f055:cf82 Nullus157 ἐννεάς
        SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="f055", ENV{ID_MODEL_ID}=="cf82", TAG+="uaccess", MODE="660"
      '';
      destination = "/etc/udev/rules.d/70-ἐννεάς.rules";
    })
    (pkgs.writeTextFile {
      name = "annepro2-udev-rules";
      text = ''
        # ID 04d9:8008 Holtek Semiconductor, Inc. USB-HID IAP
        SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="04d9", ENV{ID_MODEL_ID}=="8008", TAG+="uaccess", MODE="660"
      '';
      destination = "/etc/udev/rules.d/70-annepro2.rules";
    })
  ];
}
