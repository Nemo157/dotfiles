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
    listenAddress = "127.0.0.1";
    port = 8083;

    settings = let
      llama-cpp = pkgs.unstable.llama-cpp-rocm;
      llama-server = lib.getExe' llama-cpp "llama-server";

      stable-diffusion-cpp = pkgs.unstable.stable-diffusion-cpp-rocm;
      sd-server = lib.getExe' stable-diffusion-cpp "sd-server";

      llamaArgs = [
        llama-server
        "--host" "127.0.0.1"
        "--port" "\${PORT}"
        "--offline"
        "--log-verbosity" "4"
        "--cache-ram" "0"
        "--threads-http" "1"
      ];

      sdArgs = [
        sd-server
        "--listen-ip" "127.0.0.1"
        "--listen-port" "\${PORT}"
        "--verbose"
        "--seed" "-1"
      ];
    in
    {
      globalTTL = 300;
      performance.disabled = true;
      # Broken CORS
      sendLoadingState = false;

      models = {
        "gemma-4-12B-it-qat-UD-Q4_K_XL" = {
          cmd = lib.escapeShellArgs (llamaArgs ++ [
            "--model" (fetchHF {
              repo = "unsloth/gemma-4-12B-it-qat-GGUF";
              rev = "7102bdea62863acff919c945405ef29973113d66";
              file = "gemma-4-12B-it-qat-UD-Q4_K_XL.gguf";
              hash = "sha256-zJ/wcuCoIDQp7YVOZmLBemwrweXcpbR13Uc2yqrLwWU=";
            })

            "--fit" "off"
            "--ctx-size" "81920"

            "--model-draft" (fetchHF {
              repo = "unsloth/gemma-4-12B-it-qat-GGUF";
              rev = "7102bdea62863acff919c945405ef29973113d66";
              file = "mtp-gemma-4-12B-it.gguf";
              hash = "sha256-xQyRw18EkDgVsuiTDLuMjFvuDhqgB0jDCnuP8F0jELQ=";
            })

            "--spec-type" "draft-mtp"
            "--spec-draft-n-max" "3"
          ]);
          capabilities = {
            "in" = ["text"];
            out = ["text"];
            tools = true;
          };
        };

        "stable-diffusion-v1.5" = {
          cmd = lib.escapeShellArgs (sdArgs ++ [
            "--model" (fetchHF {
              repo = "stable-diffusion-v1-5/stable-diffusion-v1-5";
              rev = "451f4fe16113bff5a5d2269ed5ad43b0592e9a14";
              file = "v1-5-pruned.safetensors";
              hash = "sha256-GhifC+adYQakhUjnYmIH3d1wQqQY2/Nyzv0F4M26YbY=";
            })
          ]);
          checkEndpoint = "/v1/models";
          capabilities = {
            "in" = ["text"];
            out = ["image"];
          };
        };
      };
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
