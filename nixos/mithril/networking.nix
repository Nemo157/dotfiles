{
  networking = {
    hostId = "69da08a2";
    hostName = "mithril";
    useDHCP = true;
    firewall = {
      allowedTCPPorts = [
        # shairport-sync
        5000
      ];

      allowedUDPPortRanges = [
        # shairport-sync
        { from = 6001; to = 6011; }
      ];

      interfaces.tailscale0 = {
        allowedTCPPorts = [
          # sunshine
          47984 47989 48010
          # docs.rs
          3000
          # mpd
          6600 6680
        ];
        allowedUDPPorts = [
          # sunshine
          47998 47999 48000 48002 48010
        ];
      };
    };
  };
}
