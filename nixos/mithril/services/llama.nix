{ name, config, pkgs, lib, ts, ... }:
let
  fetchHF = { repo, rev, file, hash ? "" }:
    pkgs.fetchurl {
      url = "https://huggingface.co/${repo}/resolve/${rev}/${file}";
      inherit hash;
    };
in
{
  services.llama-swap = {
    enable = true;
    listenAddress = ts.ips.${name};
    port = 8083;

    settings = let
      llama-cpp = pkgs.llama-cpp.override { rocmSupport = true; };
      llama-server = lib.getExe' llama-cpp "llama-server";

      defaultArgs = [
        llama-server
        "--host" "127.0.0.1"
        "--port" "\${PORT}"
        "--offline"
        "--fit-ctx" "40960"
        "--fit-target" "3072"
        "--log-verbosity" "4"
        "--no-mmap"
        "--cache-type-k" "q8_0"
        "--cache-type-v" "f16"
        "--cache-ram" "0"
        "--threads-http" "1"
      ];

      models = {
        "gemma-4-12B-it-qat-UD-Q4_K_XL" = {
          repo = "unsloth/gemma-4-12B-it-qat-GGUF";
          rev = "7102bdea62863acff919c945405ef29973113d66";
          hash = "sha256-zJ/wcuCoIDQp7YVOZmLBemwrweXcpbR13Uc2yqrLwWU=";
        };
      };
    in
    {
      globalTTL = 300;
      performance.disabled = true;
      # Broken CORS
      sendLoadingState = false;

      models = lib.mapAttrs (name: attrs: let
        gguf = fetchHF ({ file = if attrs ? file then attrs.file else "${name}.gguf"; } // attrs);
        args = defaultArgs ++ ["--model" gguf] ++ (if attrs ? args then attrs.args else []);
      in {
        cmd = lib.escapeShellArgs args;
      }) models;
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.llama-swap.port
  ];

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
