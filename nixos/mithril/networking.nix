{
  networking = {
    hostId = "69da08a2";
    hostName = "mithril";
    useDHCP = true;
    firewall = {
      allowedTCPPorts = [
        # shairport-sync
        5000 5001
      ];

      allowedUDPPortRanges = [
        # shairport-sync
        { from = 6001; to = 6011; }
      ];

      interfaces.tailscale0 = {
        allowedTCPPorts = [
          # docs.rs
          3000
        ];
      };
    };

    interfaces.enp39s0 = {
      wakeOnLan.enable = true;
    };
  };

  systemd.network.networks = {
    "50-eth" = {
      matchConfig = {
        Name = "enp39s0";
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

    "50-wlan" = {
      matchConfig = {
        Type = "wlan";
      };
      linkConfig = {
        RequiredForOnline = "no";
      };
    };
  };
}
