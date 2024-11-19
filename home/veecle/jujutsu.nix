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
        # v0.22+
        push-bookmark-prefix = "wim/push-";
        # v0.21-
        push-branch-prefix = push-bookmark-prefix;
      };
    };
  };
}
