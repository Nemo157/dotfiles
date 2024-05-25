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
        key = "A65DC69A23649F86";
      };
    };
  };
}
