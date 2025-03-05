{ lib, pkgs, ... }: {
  programs.jujutsu = {
    settings = {
      user = {
        name = "Wim Looman";
        email = "wim.looman@veecle.io";
      };
      signing = {
        behavior = "drop";
        backend = "gpg";
        key = "wim.looman@veecle.io";
      };
      git = rec {
        sign-on-push = true;
        push-bookmark-prefix = "wim/push-";
      };
    };
  };
}
