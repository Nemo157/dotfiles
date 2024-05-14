{
  imports = [
    ./autologin.nix
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
    pam.u2f.enable = true;
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
}
