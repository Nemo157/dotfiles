{
  networking = {
    hostId = "69da08a2";
    hostName = "mithril";
    useDHCP = true;
    firewall.allowedTCPPorts = [ 5000 47984 47989 48010 ];
    firewall.allowedUDPPorts = [ 47998 47999 48000 48002 48010 ];
    firewall.allowedUDPPortRanges = [
      { from = 6001; to = 6011; }
    ];
  };
}
