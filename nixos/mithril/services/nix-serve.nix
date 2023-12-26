{ config, ... }: {
  services.nix-serve = {
    enable = true;
    port = 5069;
    bindAddress = "100.120.211.104";
    secretKeyFile = "/var/lib/nix-serve/cache-priv-key.pem";
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.nix-serve.port
  ];
}
