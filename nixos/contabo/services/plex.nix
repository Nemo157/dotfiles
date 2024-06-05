{
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 32400 ];

  services.plex = {
    enable = true;
  };
}
