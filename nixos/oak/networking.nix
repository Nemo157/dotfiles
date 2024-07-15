{ lib, config, ... }: {
  networking = {
    hostName = "oak";
    wireless.enable = true;
  };
}
