{ lib, config, pkgs, ... }: {
  programs.beets = {
    enable = true;

    settings = {
      directory = config.xdg.userDirs.music;
      library = "${config.xdg.userDirs.music}/.beets.db";

      plugins = [ "random" "bpd" "replaygain" "fetchart" ];

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
