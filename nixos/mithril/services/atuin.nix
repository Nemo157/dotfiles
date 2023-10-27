{
  services.atuin = {
    enable = true;
    host = "0.0.0.0";
    maxHistoryLength = 10000000;
  };

  systemd.services.atuin.environment = {
    RUST_LOG = "info";
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8888 ];
}
