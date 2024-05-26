{ options, lib, name, ts, ... }: {
  networking.firewall.interfaces.tailscale0.allowedUDPPorts = [ 123 ];

  networking.timeServers = lib.mkForce options.networking.timeServers.default;

  services.chrony = {
    enable = true;
    extraConfig = ''
      bindaddress ${ts.ips.${name}}
      # afaict you can't disable ipv6 listening, just bind to localhost instead
      bindaddress ::1
      allow
    '';
  };
}
