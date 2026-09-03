{ config, fetchHF, ... }: {
  services.llama-swap.models.stable-diffusion = {
    "image/stable-diffusion-v1.5" = {
      model = fetchHF {
        repo = "stable-diffusion-v1-5/stable-diffusion-v1-5";
        rev = "451f4fe16113bff5a5d2269ed5ad43b0592e9a14";
        file = "v1-5-pruned.safetensors";
        hash = "sha256-GhifC+adYQakhUjnYmIH3d1wQqQY2/Nyzv0F4M26YbY=";
      };
    };
  };
}
