{ ... }: {
  imports = [
    ./cli
    ./common.nix
    ./desktop
    ./dev
    ./personal
  ];

  home = {
    username = "nemo157";
    homeDirectory = "/Users/nemo157";
  };

  home.stateVersion = "25.11";
}
