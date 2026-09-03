{ config, fetchHF, ... }: let
  model = fetchHF {
    repo = "unsloth/Qwen3.8-27B-GGUF";
    rev = "4604b899a826000505a834e623272db5b7fd62f6";
    file = "Qwen3.8-27B-UD-IQ2_XXS.gguf";
    hash = "sha256-jRs3KX1s+YMDzTlolvNeAQid3MkEBTqcaZf3ocNbhSQ=";
  };

  baseArgs = {
    inherit model;
    fit = "off";
    ctx-size = 81920;
    reasoning-preserve = true;
    spec-type = "ngram-mod";
  };
in {
  services.llama-swap.models.llama = {
    "Qwen3.8-27B-UD-IQ2_XXS" = baseArgs;

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
