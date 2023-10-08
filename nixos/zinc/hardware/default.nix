{
  imports = [
    ./drives.nix
    ./kernel.nix
  ];

  hardware.enableRedistributableFirmware = true;

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
  };
}
