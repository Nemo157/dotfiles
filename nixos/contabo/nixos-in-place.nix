{ config, pkgs, ... }: {

  boot.kernelParams = ["boot.shell_on_fail"];
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.storePath = "/nixos/nix/store";
  boot.initrd.supportedFilesystems = [ "ext4" ];
  boot.initrd.postDeviceCommands = ''
    mkdir -p /mnt-root/old-root ;
    mount -t ext4 /dev/sda2 /mnt-root/old-root ;
  '';
  fileSystems = {
    "/" = {
      device = "/old-root/nixos";
      fsType = "none";
      options = [ "bind" ];
    };
    "/old-root" = {
      device = "/dev/sda2";
      fsType = "ext4";
    };
  };

}
