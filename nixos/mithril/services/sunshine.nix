{ name, ts, config, pkgs, ... }: {
  services.sunshine = {
    enable = true;
    settings = {
      bind_address = ts.ips.${name};
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.sunshine.settings.port
  ];
}
