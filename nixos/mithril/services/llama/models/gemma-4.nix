{ config, ... }: let
  inherit (config.lib.llama-swap) fetchHF mkLlama;
in {
  services.llama-swap.settings.models = {
    "gemma-4-12B-it-qat-UD-Q4_K_XL" = let
      repo = "unsloth/gemma-4-12B-it-qat-GGUF";
      rev = "7102bdea62863acff919c945405ef29973113d66";
    in mkLlama [
      "--model" (fetchHF {
        inherit repo rev;
        file = "gemma-4-12B-it-qat-UD-Q4_K_XL.gguf";
        hash = "sha256-zJ/wcuCoIDQp7YVOZmLBemwrweXcpbR13Uc2yqrLwWU=";
      })

      "--fit" "off"
      "--ctx-size" "81920"

      "--model-draft" (fetchHF {
        inherit repo rev;
        file = "mtp-gemma-4-12B-it.gguf";
        hash = "sha256-xQyRw18EkDgVsuiTDLuMjFvuDhqgB0jDCnuP8F0jELQ=";
      })

      "--spec-type" "draft-mtp,ngram-mod"
    ];

    "gemma-4-26B-A4B-it-qat-UD-Q4_K_XL" = let
      repo = "unsloth/gemma-4-26B-A4B-it-qat-GGUF";
      rev = "7b92b5b28818151e8669af2e45e88d6086f490dd";
    in mkLlama [
      "--model" (fetchHF {
        inherit repo rev;
        file = "gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf";
        hash = "sha256-p8W8cV9f+OmaPokBzn0rQrQCxmm/JPfFJQdHYz0PWJE=";
      })

      "--fit" "off"
      "--ctx-size" "81920"

      "--n-cpu-moe" "10"
      "--load-mode" "none"

      "--model-draft" (fetchHF {
        inherit repo rev;
        file = "mtp-gemma-4-26B-A4B-it.gguf";
        hash = "sha256-cnLZdZXw1MdL17YjSSt9var9i3xy8ymoJwuk7KaPdoo=";
      })

      "--spec-type" "draft-mtp,ngram-mod"
    ];
  };
}
