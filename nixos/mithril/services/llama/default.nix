{ name, config, pkgs, lib, ts, ... }: {
  imports = [
    ./models
  ];

  services.llama-swap = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 8083;

    settings = {
      globalTTL = 300;
      performance.disabled = true;
      # Broken CORS
      sendLoadingState = false;
    };
  };

  services.caddy.virtualHosts."https://llama.${ts.domain}" = {
    extraConfig = ''
      import tailscale "llama"
      reverse_proxy 127.0.0.1:${toString config.services.llama-swap.port}
    '';
  };

  systemd.services.llama-swap-unload = {
    description = "Unload llama-swap models before sleep";
    before = [ "sleep.target" ];
    wantedBy = [ "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.curl} -X POST http://127.0.0.1:${toString config.services.llama-swap.port}/api/models/unload";
    };
  };
}
