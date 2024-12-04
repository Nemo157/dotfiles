{
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      open = false;
      powerManagement = {
        enable = true;
      };
    };
  };

  # required for hardware.nvidia to setup the driver, even when not using x11
  services.xserver.videoDrivers = ["nvidia"];
}
