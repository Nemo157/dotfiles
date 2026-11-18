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
      revsets = {
        git-sign-on-push = "~signed() & mine()";
      };
      templates = {
        git_push_bookmark = ''"wim/push-" ++ change_id.short()'';
        # commit_trailers = "format_signed_off_by_trailer(self)";
      };
    };
  };
}
