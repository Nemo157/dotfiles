{
  services.samba = {
    enable = true;
    nmbd.enable = false;
    winbindd.enable = false;
    settings = {
      global = {
        "map to guest" = "Bad User";
      };
      videos = {
        path = "/srv/videos";
        "read only" = true;
        browseable = "yes";
        "guest ok" = "yes";
      };
    };
  };

  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [ 445 ];
    allowedUDPPorts = [ ];
  };
}
