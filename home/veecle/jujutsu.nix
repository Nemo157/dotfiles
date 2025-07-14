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
      git = {
        sign-on-push = true;
      };
      templates = {
        git_push_bookmark = ''"wim/push-" ++ change_id.short()'';
      };
    };
  };
}
