{ name, ts, ... }: {
  services.influxdb = {
    enable = true;
    extraConfig = {
      http = {
        bind-address = "${ts.ips.${name}}:8086";
      };
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8086 ];
}
