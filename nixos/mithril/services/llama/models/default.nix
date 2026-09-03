{ config, pkgs, lib, ... }: {
  imports = [
    ./gemma-4.nix
    ./qwen-3.8.nix
    ./audio-cpp.nix
    ./stable-diffusion.nix
  ];

  config.lib.llama-swap = {
    fetchHF = { repo, rev, file, hash ? "" }:
      pkgs.fetchurl {
        url = "https://huggingface.co/${repo}/resolve/${rev}/${file}";
        inherit hash;
      };

    mkLlama = args: {
      cmd = lib.escapeShellArgs ([
        (lib.getExe' pkgs.unstable.llama-cpp-rocm "llama-server")
        "--host" "127.0.0.1"
        "--port" "\${PORT}"
        "--offline"
        "--log-verbosity" "4"
        "--cache-ram" "0"
        "--threads-http" "1"
      ] ++ args);

      capabilities = {
        "in" = ["text"];
        out = ["text"];
        tools = true;
      };
    };

    mkStableDiffusion = args: {
      cmd = lib.escapeShellArgs ([
        (lib.getExe' pkgs.unstable.stable-diffusion-cpp-rocm "sd-server")
        "--listen-ip" "127.0.0.1"
        "--listen-port" "\${PORT}"
        "--verbose"
        "--seed" "-1"
      ] ++ args);

      checkEndpoint = "/v1/models";

      capabilities = {
        "in" = ["text"];
        out = ["image"];
      };
    };

    mkAudio = model: let
      audio-cpp-rocm = pkgs.audio-cpp.rocm.override {
        rocmGpuTargets = ["gfx1201"];
      };
      json = pkgs.formats.json {};
    in {
      cmd = lib.escapeShellArgs [
        (lib.getExe' audio-cpp-rocm "audiocpp_server")
        "--config" (json.generate "audiocpp-server.config" { models = [model]; })
        "--host" "127.0.0.1"
        "--port" "\${PORT}"
        "--backend" "rocm"
        "--log"
        "--cors-origins" "*"
      ];

      capabilities = {
        "in" = ["text"];
        out = ["audio"];
      };
    };
  };
}
