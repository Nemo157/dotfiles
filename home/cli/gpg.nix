{ config, pkgs, ... }: {
  programs.gpg = {
    enable = true;
    settings = {
      keyserver = "hkps://keys.openpgpg.org";
    };
  };
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-curses;
  };
}
