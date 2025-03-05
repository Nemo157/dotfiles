{ lib, pkgs, ... }: {
  programs.jujutsu = {
    settings = {
      user = {
        name = "Wim Looman";
        email = "git@nemo157.com";
      };
      signing = {
        behavior = "drop";
        backend = "gpg";
        key = "git@nemo157.com";
      };
      git = {
        sign-on-push = true;
      };
    };
  };
}
