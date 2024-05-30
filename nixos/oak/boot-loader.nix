{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    initrd.luks.devices = {
      "luks-b2f89fdf-6cce-4f69-b443-f83e0638de61".device = "/dev/disk/by-uuid/b2f89fdf-6cce-4f69-b443-f83e0638de61";
    };
  };
}
