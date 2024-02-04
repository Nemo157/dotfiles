{ lib, config, pkgs, ... }: {
  programs.beets = {
    enable = true;

    mpdIntegration.enableUpdate = true;

    settings = {
      directory = config.xdg.userDirs.music;
      library = "${config.xdg.userDirs.music}/.beets.db";

      plugins = [
        "fetchart"
        "info"
        "mbsync"
        "missing"
        "random"
        "replaygain"
      ];

      import = {
        move = true;
      };

      replaygain = {
        backend = "ffmpeg";
      };

      fetchart = {
        sources = [ "filesystem" "coverart" ];
      };
    };
  };
}
