{ pkgs, ... }: {
  imports = [
    ./editorconfig.nix
    ./gh.nix
    ./git
    ./jujutsu.nix
    ./rust
    ./yamllint.nix
    ./claude
    ./opencode
  ];

  services.ollama = {
    enable = true;
    environmentVariables = {
      OLLAMA_NO_CLOUD = "1";
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
    };
  };
}
