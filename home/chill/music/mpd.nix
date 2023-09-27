{ lib, config, pkgs, ... }: {
  home.packages = [ pkgs.mpc-cli ];

  services.mpd = {
    enable = true;
    network.startWhenNeeded = true;
    extraConfig = ''
      auto_update "yes"
      follow_outside_symlinks "no"
      follow_inside_symlinks "yes"
      replaygain "auto"
      filesystem_charset "UTF-8"
    '';
  };

  age.secrets.listenbrainz-token.file = ./listenbrainz-token.age;

  services.mpd-mpris.enable = true;
  services.mpris-proxy.enable = true;

  services.listenbrainz-mpd = {
    enable = true;
    settings = {
      submission = {
        token_file = config.age.secrets.listenbrainz-token.path;
      };
    };
  };
}
