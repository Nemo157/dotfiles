{
  imports = [
    ./avahi.nix
    ./devmon.nix
    ./pipewire.nix
  ];

  services = {
    ddccontrol.enable = true;
  };
}
