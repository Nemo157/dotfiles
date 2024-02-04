{ lib, config, pkgs, ... }: {
  programs.beets = {
    enable = true;

    mpdIntegration.enableUpdate = true;

    settings = {
      directory = config.xdg.userDirs.music;
      library = "${config.xdg.userDirs.music}/.beets.db";

      plugins = [
        "embedart"
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

      embedart = {
        auto = false; # Actually using it for the cli command to extract
      };

      fetchart = {
        sources = [ "filesystem" "coverart" ];
      };
    };
  };
}
