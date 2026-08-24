{ name, config, pkgs, lib, ts, ... }:
let
  fetchHF = { repo, rev, file, hash ? "" }:
    pkgs.fetchurl {
      url = "https://huggingface.co/${repo}/resolve/${rev}/${file}";
      inherit hash;
    };

  json = pkgs.formats.json {};
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

      audio-cpp = pkgs.audio-cpp.rocm.override {
        rocmGpuTargets = ["gfx1201"];
        models = ["supertonic" "voxcpm2" "omnivoice"];
      };
      audio-cpp-server = lib.getExe' audio-cpp "audiocpp_server";

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

            "--spec-type" "draft-mtp,ngram-mod"
          ]);
          capabilities = {
            "in" = ["text"];
            out = ["text"];
            tools = true;
          };
        };

        "gemma-4-26B-A4B-it-qat-UD-Q4_K_XL" = {
          cmd = lib.escapeShellArgs (llamaArgs ++ [
            "--model" (fetchHF {
              repo = "unsloth/gemma-4-26B-A4B-it-qat-GGUF";
              rev = "7b92b5b28818151e8669af2e45e88d6086f490dd";
              file = "gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf";
              hash = "sha256-p8W8cV9f+OmaPokBzn0rQrQCxmm/JPfFJQdHYz0PWJE=";
            })

            "--fit" "off"
            "--ctx-size" "81920"

            "--n-cpu-moe" "10"
            "--load-mode" "none"

            "--model-draft" (fetchHF {
              repo = "unsloth/gemma-4-26B-A4B-it-qat-GGUF";
              rev = "7b92b5b28818151e8669af2e45e88d6086f490dd";
              file = "mtp-gemma-4-26B-A4B-it.gguf";
              hash = "sha256-cnLZdZXw1MdL17YjSSt9var9i3xy8ymoJwuk7KaPdoo=";
            })

            "--spec-type" "draft-mtp,ngram-mod"
          ]);
          capabilities = {
            "in" = ["text"];
            out = ["text"];
            tools = true;
          };
        };

        "Qwen3.6-35B-A3B-UD-IQ4_XS" = {
          cmd = lib.escapeShellArgs (llamaArgs ++ [
            "--model" (fetchHF {
              repo = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF";
              rev = "5bc3e238d916f48a861bac2f8a1990a0e9b7e98d";
              file = "Qwen3.6-35B-A3B-UD-IQ4_XS.gguf";
              hash = "sha256-3yengENbe0XCWXU2ES6jywkfhUTD0MMxjZ9CWLMfet8=";
            })

            "--fit" "off"
            "--ctx-size" "81920"

            "--n-cpu-moe" "25"
            "--load-mode" "none"

            "--spec-type" "draft-mtp,ngram-mod"
            "--spec-draft-n-max" "3"
          ]);
          capabilities = {
            "in" = ["text"];
            out = ["text"];
            tools = true;
          };
        };

        "Qwen3.8-27B-UD-IQ2_XXS" = {
          cmd = lib.escapeShellArgs (llamaArgs ++ [
            "--model" (fetchHF {
              repo = "unsloth/Qwen3.8-27B-GGUF";
              rev = "4604b899a826000505a834e623272db5b7fd62f6";
              file = "Qwen3.8-27B-UD-IQ2_XXS.gguf";
              hash = "sha256-jRs3KX1s+YMDzTlolvNeAQid3MkEBTqcaZf3ocNbhSQ=";
            })

            "--fit" "off"
            "--ctx-size" "81920"

            "--spec-type" "ngram-mod"
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

        "audio-cpp" = {
          cmd = lib.escapeShellArgs [
            audio-cpp-server
            "--config" (json.generate "audiocpp-server.config" {
              models = [{
                id = "supertonic-3";
                family = "supertonic";
                path = (fetchHF {
                  repo = "audio-cpp/audio.cpp-gguf";
                  rev = "359189ae3925638d419866d505c180a91815d8b8";
                  file = "Supertonic-3-GGUF/supertonic-3-orig.gguf";
                  hash = "sha256-r4FEhqC8lRP7Nq+r2bEVWtFPssNqEHrG/+Yuqa2vtmI=";
                });
                task = "tts";
                mode = "streaming";
                load_options = {
                  language = "english";
                };
                voice_presets = {
                  M1.voice_id = "M1";
                  M2.voice_id = "M2";
                  M3.voice_id = "M3";
                  F1.voice_id = "F1";
                  F2.voice_id = "F2";
                  F3.voice_id = "F3";
                };
              } {
                id = "voxcpm2";
                family = "voxcpm2";
                path = (fetchHF {
                  repo = "audio-cpp/audio.cpp-gguf";
                  rev = "359189ae3925638d419866d505c180a91815d8b8";
                  file = "VoxCPM2-GGUF/voxcpm2-orig.gguf";
                  hash = "sha256-ExgeAeFdVVyernd5Ym6zlcaTNPFelIyeomXd83q1CxY=";
                });
                task = "tts";
                mode = "streaming";
                load_options = {
                  language = "english";
                };
              } {
                id = "omnivoice";
                family = "omnivoice";
                path = (fetchHF {
                  repo = "audio-cpp/audio.cpp-gguf";
                  rev = "359189ae3925638d419866d505c180a91815d8b8";
                  file = "OmniVoice-GGUF/omnivoice-f16.gguf";
                  hash = "sha256-dCG2w4c1HSzc5+uLkx+ieXOdYo7yWs1P8gYqcObhq2M=";
                });
                task = "tts";
                mode = "streaming";
                load_options = {
                  language = "english";
                };
                voice_presets = {
                  # female.instruct = "female, young adult, moderate pitch";
                };
              }];
            })
            "--host" "127.0.0.1"
            "--port" "\${PORT}"
            "--backend" "rocm"
            "--log"
            "--cors-origins" "*"
          ];
          aliases = ["supertonic-3" "voxcpm2" "omnivoice"];
          capabilities = {
            "in" = ["text"];
            out = ["audio"];
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
