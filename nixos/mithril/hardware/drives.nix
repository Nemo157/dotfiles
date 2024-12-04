{ config, ... }: {
  boot = {
    initrd = {
      supportedFilesystems = [ "zfs" ];
      availableKernelModules = [ "zfs" "nvme" ];
      kernelModules = [ "usb_storage" ];

      luks.devices = {
        root = {
          device = "/dev/disk/by-uuid/2a05a31a-dc60-4f00-94a7-dbf4d4e94900";
          preLVM = true;
          bypassWorkqueues = true;
          allowDiscards = true;
          keyFileSize = 4096;
          keyFile = "/dev/disk/by-id/usb-Intenso_Micro_Line_E405AC7369FC94-0:0";
          fallbackToPassword = true;
        };
      };
    };

    supportedFilesystems = [ "zfs" ];

    extraModprobeConfig = ''
      options zfs zfs_arc_max=17179869184
    '';
  };

  fileSystems = {
    "/" = { device = "rpool/nixos/root"; fsType = "zfs"; };
    "/home" = { device = "rpool/nixos/home"; fsType = "zfs"; };
    "/home/nemo157/sources" = { device = "rpool/nixos/home/nemo157/sources"; fsType = "zfs"; };
    "/home/nemo157/.local/share/atuin" = { device = "rpool/nixos/home/nemo157/.local-share-atuin"; fsType = "zfs"; };
    "/home/nemo157/.var" = { device = "rpool/nixos/home/nemo157/.var"; fsType = "zfs"; };
    "/home/nemo157/.var/app/com.valvesoftware.Steam" = { device = "rpool/nixos/home/nemo157/.var/app-com.valvesoftware.Steam"; fsType = "zfs"; };
    "/home/nemo157/.var/app/at.vintagestory.VintageStory" = { device = "rpool/nixos/home/nemo157/.var/app-at.vintagestory.VintageStory"; fsType = "zfs"; };
    "/home/nemo157/sources/rustfmt/target" = { device = "rpool/nixos/home/nemo157/sources/rustfmt-target"; fsType = "zfs"; };
    "/home/nemo157/.var/app/org.fractalsoft.Starsector" = { device = "rpool/nixos/home/nemo157/.var/app-org.fractalsoft.Starsector"; fsType = "zfs"; };
    "/home/nemo157/.var/app/org.prismlauncher.PrismLauncher" = { device = "rpool/nixos/home/nemo157/.var/app-org.prismlauncher.PrismLauncher"; fsType = "zfs"; };
    "/home/nemo157/sources/docs.rs/.rustwide-docker" = { device = "rpool/nixos/home/nemo157/sources/docs.rs-.rustwide-docker"; fsType = "zfs"; };
    "/home/nemo157/sources/cargo/target" = { device = "rpool/nixos/home/nemo157/sources/cargo-target"; fsType = "zfs"; };

    "/var/lib" = { device = "rpool/nixos/var/lib"; fsType = "zfs"; };
    "/var/lib/docker" = { device = "rpool/nixos/var/lib/docker"; fsType = "zfs"; };
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
