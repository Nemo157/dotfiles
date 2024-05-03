{ pkgs, ... }: {
  imports = [
    ./services
  ];

  nix = {
    package = pkgs.nixFlakes;
    settings = {
      experimental-features = "nix-command flakes";
    };
  };
}
