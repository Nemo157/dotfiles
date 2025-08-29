{
  imports = [
    ./bluetooth.nix
    ./drives.nix
    ./firmware.nix
    ./kernel.nix
    ./steam.nix
  ];

  hardware.openrazer = {
    enable = true;
    users = ["nemo157"];
  };
}
