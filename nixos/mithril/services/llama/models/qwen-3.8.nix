{ lib, config, fetchHF, ... }: let
  baseArgs = {
    model = fetchHF {
      repo = "unsloth/Qwen3.8-27B-GGUF";
      rev = "4ca720788d1e01f1bff70c033e0d0028fd02e502";
      file = "Qwen3.8-27B-UD-IQ2_XXS.gguf";
      hash = "sha256-55LY+zFC/m2RcYdtbaD3HwWnEChxjevHLb7JP/ZF5n0=";
    };

    # model-draft = fetchHF {
    #   repo = "unsloth/Qwen3.8-27B-GGUF";
    #   rev = "4ca720788d1e01f1bff70c033e0d0028fd02e502";
    #   file = "MTP/mtp-Qwen3.8-27B-Q4_0.gguf";
    #   hash = "sha256-UNnOWm2jgbvPsxBhz3PflKkOb6+O/t3uN5qcuPFQHG4=";
    # };

    mmproj = fetchHF {
      repo = "unsloth/Qwen3.8-27B-GGUF";
      rev = "4ca720788d1e01f1bff70c033e0d0028fd02e502";
      file = "mmproj-F16.gguf";
      hash = "sha256-y7hBqe4GNrLsFy9buN8uqN/rAekP58YSZYHWYqC05D4=";
    };

    fit = "off";

    cache-type-k = "q8_0";
    cache-type-v = "q8_0";

    ctx-size = 98304;
    reasoning-preserve = true;

    spec-type = "ngram-mod";
  };
in {
  services.llama-swap.models.llama = {
    "Qwen3.8-27B-UD-IQ2_XXS" = baseArgs;

    "Qwen3.8-27B-UD-IQ2_XXS-slow" = baseArgs // {
      gpu-layers = 32;
      ctx-size = 262144;
    };

    "Qwen3.8-27B-UD-IQ4_XS" = {
      model = fetchHF {
        repo = "unsloth/Qwen3.8-27B-GGUF";
        rev = "4ca720788d1e01f1bff70c033e0d0028fd02e502";
        file = "Qwen3.8-27B-UD-IQ4_XS.gguf";
        hash = "sha256-QPrEBQ6UA5fb8TCHr9UPRzShGAW/nWXvjd10g0cOYZk=";
      };

      fit = "off";

      cache-type-k = "q8_0";
      cache-type-v = "q8_0";
      ctx-size = 262144;

      gpu-layers = 32;

      reasoning-preserve = true;

      spec-type = "ngram-mod";
    };

    "Qwen3.8-27B-UD-IQ2_XXS-Samantha" = baseArgs // {
      lora = fetchHF {
        repo = "Lathly/Qwen3.8-27B-Samantha_Uncensored_1.1_LoRA";
        rev = "1a87bbacbc7d02ff7da54f66b0c382c692df3bb9";
        file = "Qwen3.8-27B-Samantha-LoRA-qwen35.gguf";
        hash = "sha256-w52xqReSlvk3MwNfXvO0lCbmAXxxdMH7bjQS+5c2MSU=";
      };
    };
  };
}
