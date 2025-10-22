{ config, ... }: {
  age.secrets.veecle-linear-api-key.file = ./linear-api-key.age;

  programs.linear-cli = {
    enable = true;
    environmentFile = config.age.secrets.veecle-linear-api-key.path;
  };
}
