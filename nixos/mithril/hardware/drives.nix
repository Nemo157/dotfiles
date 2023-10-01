{ config, ... }: {
  boot = {
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

    initrd = {
      supportedFilesystems = [ "zfs" ];
      availableKernelModules = [ "zfs" "nvme" ];

      luks.devices = {
        root = {
          device = "/dev/disk/by-uuid/2a05a31a-dc60-4f00-94a7-dbf4d4e94900";
          preLVM = true;
          bypassWorkqueues = true;
          allowDiscards = true;
        };
      };
    };

    supportedFilesystems = [ "zfs" ];
  };

  fileSystems = {
    "/" = { device = "rpool/nixos/root"; fsType = "zfs"; };
    "/home" = { device = "rpool/nixos/home"; fsType = "zfs"; };
    "/var/lib" = { device = "rpool/nixos/var/lib"; fsType = "zfs"; };
    "/var/log" = { device = "rpool/nixos/var/log"; fsType = "zfs"; };
    "/boot" = { device = "rpool/nixos/boot"; fsType = "zfs"; };
    "/boot/efis/nvme-CT2000P3PSSD8_2309E6B34606-part3" = {
      device = "/dev/disk/by-uuid/28C9-03CC";
      fsType = "vfat";
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/fb3fd87f-27ad-42ac-b997-41958eaa9137"; }
  ];

  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
  };
}
