{ lib, config, fetchHF, ... }: let
  gemma4-12B = {
    repo = "unsloth/gemma-4-12B-it-qat-GGUF";
    rev = "7102bdea62863acff919c945405ef29973113d66";
  };
  gemma4-26B-A4B = {
      repo = "unsloth/gemma-4-26B-A4B-it-qat-GGUF";
      rev = "7b92b5b28818151e8669af2e45e88d6086f490dd";
  };
in {
  services.llama-swap.models.llama = {
    "gemma-4-12B-it-qat-UD-Q4_K_XL" = {
      model = fetchHF (gemma4-12B // {
        file = "gemma-4-12B-it-qat-UD-Q4_K_XL.gguf";
        hash = "sha256-zJ/wcuCoIDQp7YVOZmLBemwrweXcpbR13Uc2yqrLwWU=";
      });
      mmproj = fetchHF (gemma4-12B // {
        file = "mmproj-F16.gguf";
        hash = "sha256-7MTpMSjag2O32/IZPquYzxFCNT9SzqoMlcCHKZeqrdM=";
      });
      fit = "off";
      cache-type-k = "q8_0";
      cache-type-v = "q8_0";
      ctx-size = 81920;
      model-draft = fetchHF (gemma4-12B // {
        file = "mtp-gemma-4-12B-it.gguf";
        hash = "sha256-xQyRw18EkDgVsuiTDLuMjFvuDhqgB0jDCnuP8F0jELQ=";
      });
      spec-type = "draft-mtp,ngram-mod";
    };

    "gemma-4-26B-A4B-it-qat-UD-Q4_K_XL" = {
      model = fetchHF (gemma4-26B-A4B // {
        file = "gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf";
        hash = "sha256-p8W8cV9f+OmaPokBzn0rQrQCxmm/JPfFJQdHYz0PWJE=";
      });
      mmproj = fetchHF (gemma4-26B-A4B // {
        file = "mmproj-F16.gguf";
        hash = "sha256-0A8hGn1Pf7Gb2bddjpNC7M/7WSCwj9lWIWdWD9/MXdE=";
      });
      fit = "off";
      cache-type-k = "q8_0";
      cache-type-v = "q8_0";
      ctx-size = 81920;
      n-cpu-moe = 10;
      # load-mode = "none";
      model-draft = fetchHF (gemma4-26B-A4B // {
        file = "mtp-gemma-4-26B-A4B-it.gguf";
        hash = "sha256-cnLZdZXw1MdL17YjSSt9var9i3xy8ymoJwuk7KaPdoo=";
      });
      spec-type = "draft-mtp,ngram-mod";
    };
  };
}
