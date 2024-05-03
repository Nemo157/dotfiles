{ name, config, ts, ... }: {
  services.nix-serve = {
    enable = true;
    port = 5069;
    bindAddress = ts.ips.${name};
    secretKeyFile = "/var/lib/nix-serve/cache-priv-key.pem";
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.nix-serve.port
  ];
}
