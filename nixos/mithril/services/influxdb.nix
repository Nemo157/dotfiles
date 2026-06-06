{ name, ts, ... }: {
  services.influxdb = {
    enable = true;
    settings = {
      http = {
        bind-address = "${ts.ips.${name}}:8086";
      };
      reporting-disabled = true;
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8086 ];
}
