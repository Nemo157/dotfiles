{
  services.samba = {
    enable = true;
    enableNmbd = false;
    enableWinbindd = false;
    shares = {
      videos = {
        path = "/srv/videos";
        "read only" = true;
        browseable = "yes";
        "guest ok" = "yes";
      };
    };
    extraConfig = ''
      map to guest = Bad User
    '';
  };


  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [ 445 ];
    allowedUDPPorts = [ ];
  };
}
