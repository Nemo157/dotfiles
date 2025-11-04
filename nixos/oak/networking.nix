{ lib, config, ... }: {
  networking = {
    hostName = "oak";
    wireless.enable = true;
  };

  services.tailscale = {
    enable = true;
  };
}
