{
  boot.initrd.luks.devices = {
    "luks-83e617bd-c53f-488b-84e4-6dde7e94c0a8" = {
      device = "/dev/disk/by-uuid/83e617bd-c53f-488b-84e4-6dde7e94c0a8";
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/e006e14d-eb63-4c57-9176-66855b4bf4b2";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/5B0E-4EB6";
      fsType = "vfat";
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/b1f3f2cf-4af4-4e40-a175-42fc87cc4063"; }
  ];
}
