{ lib, config, pkgs, ts, ... }: {
  home.packages = [ pkgs.mpc-cli ];

  services.mpd = {
    enable = true;
    network = {
      startWhenNeeded = true;
      listenAddress = ts.self.ip;
      port = 6600;
    };
    extraConfig = ''
      auto_update "yes"
      follow_outside_symlinks "no"
      follow_inside_symlinks "yes"
      replaygain "auto"
      filesystem_charset "UTF-8"
      audio_output {
        type "pipewire"
        name "pipewire"
      }
      audio_output {
        type "httpd"
        name "httpd"
        port "6680"
        bind_to_address "${ts.self.ip}"
        encoder "lame"
        quality "2"
      }
      default_permissions "read,add,player,control,admin"
      zeroconf_enabled "no"
    '';
  };

  # "$XDG_RUNTIME_DIR/mpd/socket" would be better, but mpd-mpris doesn't support
  home.sessionVariables.MPD_HOST = ts.self.host;

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
