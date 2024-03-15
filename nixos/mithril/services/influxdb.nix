{ ts, ... }: {
  services.influxdb = {
    enable = true;
    extraConfig = {
      http = {
        bind-address = "${ts.self.ip}:8086";
      };
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8086 ];
}
