{ lib, config, pkgs, ... }:
let
  ffmpeg-fdk-aac = pkgs.ffmpeg.override {
    withUnfree = true;
    withFdkAac = true;
  };
in {
  home.packages = [
    pkgs.ffmpeg
  ];

  programs.beets = {
    enable = true;

    mpdIntegration = {
      enableUpdate = true;
    };

    settings = {
      directory = config.xdg.userDirs.music;
      library = "${config.xdg.userDirs.music}/.beets.db";

      plugins = [
        "convert"
        "embedart"
        "fetchart"
        "fromfilename"
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

      convert = {
        # can't use `auto = true` as that ignores the `dest` and instead
        # replaces the files that get put into the library, will have to
        # `beets convert` manually after importing new albums to generate
        copy_album_art = true;
        album_art_maxwidth = 1024;
        dest = "${config.home.homeDirectory}/Music/Low";
        embed = false;
        max_bitrate = 128;
        formats.aac = {
          command = "${lib.getExe ffmpeg-fdk-aac} -i $source -y -vn -c:a libfdk_aac -vbr 4 $dest";
          extension = "m4a";
        };
        format = "aac";
      };
    };
  };
}
