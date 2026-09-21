{pkgs, ...}: {
  boot.kernelPatches = [
    {
      name = "amd-bsb-fix";
      patch = pkgs.fetchpatch {
        url = "https://vronlinux.org/docs/hardware/bigscreen-beyond/bigscreen-beyond-kernel-7.0.patch";
        hash = "sha256-emlV3SRC784DnKpPIoKS87yuA+RwM+ZZNQ7UAhuptkA=";
      };
    }
    {
      name = "amd-bsb-dsc-fix";
      patch = pkgs.fetchpatch {
        url = "https://vronlinux.org/docs/hardware/bigscreen-beyond/amd-bsb-dsc-fix-7.1.patch";
        hash = "sha256-ybFZsaOBcXKa4U/BoBeppxHGZudLTsV5oVnm+QXLzrU=";
      };
    }
  ];

  systemd.user.services.monado = {
    environment = {
      LH_OVERRIDE_IPD_MM = "65";
    };
  };

  services.udev.extraRules = ''
    # Bigscreen Beyond
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0101", MODE="0660", GROUP="users"
    # Bigscreen Beyond Firmware Mode
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="4004", MODE="0660", GROUP="users"
    # Bigscreen Beyond Error Mode
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="1001", MODE="0660", GROUP="users"

    # Bigscreen Bigeye
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0202", MODE="0660", GROUP="users"
    # Bigscreen Bigeye DFU Mode
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0282", MODE="0660", GROUP="users"
  '';
}
