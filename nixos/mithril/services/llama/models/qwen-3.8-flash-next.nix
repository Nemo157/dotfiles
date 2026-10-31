{ lib, pkgs, config, fetchHF, ... }: let
  repo = "unsloth/Qwen3.8-Flash-Next-GGUF";
  rev = "38bb39ee97821de2c9009abb7e93950eec396e66";

  hashes = [
    "sha256-Jo+B/e3zFJpTjyUjCJJ6TV0fbgYsF4VopR47UZdE+Kg="
    "sha256-z+YAsja4jH+tFhOlyl6DufK+tjy9RMMrK+UKRHR8aV8="
    "sha256-8ZEro0x5Qn0ilaWNyytzK1kxr1vvejc8YFV6V9nuclA="
  ];

  pad = lib.fixedWidthNumber 5;

  files = pkgs.linkFarm "qwen3.8-flash-next-ud-iq3_xxs" (lib.imap1 (i: hash: rec {
    name = "Qwen3.8-Flash-Next-UD-IQ3_XXS-${pad i}-of-${pad (builtins.length hashes)}.gguf";
    path = fetchHF {
      inherit repo rev hash;
      file = "UD-IQ3_XXS/${name}";
    };
  }) hashes);

in {
  services.llama-swap.models.llama = {
    "Qwen3.8-Flash-Next-UD-IQ3_XXS" = {
      model = "${files}/Qwen3.8-Flash-Next-UD-IQ3_XXS-00001-of-00003.gguf";

      fit = "off";
      n-gpu-layers = "all";
      load-mode = "mmap";
      lazy-mode = "on";

      cache-type-k = "q8_0";
      cache-type-v = "q8_0";

      ctx-size = 262144;
      reasoning-preserve = true;

      cpu-moe = true;

      override-kv = "qwen4exp.attention.indexer.top_k=int:4096";

      spec-type = "ngram-mod";
    };
  };
}
