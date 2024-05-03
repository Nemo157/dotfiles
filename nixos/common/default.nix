{ pkgs, ... }: {
  imports = [
    ./services
    ./users.nix
  ];

  nix = {
    package = pkgs.nixFlakes;
    settings = {
      experimental-features = "nix-command flakes";
    };
  };
}
