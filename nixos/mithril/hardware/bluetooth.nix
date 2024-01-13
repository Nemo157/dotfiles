{
  hardware.bluetooth = {
    enable = true;
    settings = {
      General = {
        Experimental = true;
      };
    };
  };
  boot.extraModprobeConfig = ''
    options bluetooth disable_ertm=1
  '';
}
