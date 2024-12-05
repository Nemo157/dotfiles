{ lib, pkgs, ... }: {
  programs.jujutsu = {
    settings = {
      user = {
        name = "Wim Looman";
        email = "wim.looman@veecle.io";
      };
      signing = {
        sign-all = true;
        backend = "gpg";
        key = "wim.looman@veecle.io";
      };
      git = rec {
        push-bookmark-prefix = "wim/push-";
      };
    };
  };
}
