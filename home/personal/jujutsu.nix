{ lib, pkgs, ... }: {
  programs.jujutsu = {
    settings = {
      user = {
        name = "Wim Looman";
        email = "git@nemo157.com";
      };
      signing = {
        behavior = "drop";
      };
    };
  };
}
