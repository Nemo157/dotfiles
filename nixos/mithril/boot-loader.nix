{
  boot.loader = {
    systemd-boot.enable = true;
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot/efis/nvme-CT2000P3PSSD8_2309E6B34606-part3";
    };
  };
}
