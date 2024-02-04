{ config, ts, ... }: {
  services.nix-serve = {
    enable = true;
    port = 5069;
    bindAddress = ts.self.ip;
    secretKeyFile = "/var/lib/nix-serve/cache-priv-key.pem";
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.nix-serve.port
  ];
}
