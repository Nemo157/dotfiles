{
  hardware.bluetooth.enable = true;
  boot.extraModprobeConfig = ''
    options bluetooth disable_ertm=1
  '';
}
