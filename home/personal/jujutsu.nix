{ lib, pkgs, ... }: {
  programs.jujutsu = {
    settings = {
      user = {
        name = "Wim Looman";
        email = "git@nemo157.com";
      };
      signing = {
        sign-all = true;
        backend = "gpg";
        key = "git@nemo157.com";
      };
    };
  };
}
