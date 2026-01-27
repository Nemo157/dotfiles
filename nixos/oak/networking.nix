{ lib, config, ... }: {
  networking = {
    hostName = "oak";
    wireless.enable = true;
    firewall.interfaces.docker0.allowedTCPPorts = [ 3000 ];
    firewall.interfaces."br+".allowedTCPPorts = [ 3000 ];
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
