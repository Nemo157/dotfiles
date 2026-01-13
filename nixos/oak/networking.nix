{ lib, config, ... }: {
  networking = {
    hostName = "oak";
    wireless.enable = true;
  };

  services.tailscale = {
    enable = true;
  };

  systemd.network.networks = {
    "50-wlan" = {
      matchConfig = {
        Type = "wlan";
      };
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
        IPv6LinkLocalAddressGenerationMode = "random";
        IPv6PrivacyExtensions = true;
      };
      linkConfig = {
        RequiredForOnline = "yes";
      };
    };
  };
}
