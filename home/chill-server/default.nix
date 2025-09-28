{ pkgs, config, ... }: {
  imports = [
    ./shairport-sync.nix
  ];

  programs.yt-dlp = {
    enable = true;
    settings = {
      download-archive = "${config.xdg.stateHome}/yt-dlp/download.archive";

      embed-chapters = true;
      embed-metadata = true;
      embed-subs = true;
      embed-thumbnail = true;

      extractor-args = "youtube:player-client=default,-tv_simply";

      format = "bv[vbr<=5632]+ba";

      live-from-start = true;

      merge-output-format = "mp4";

      output = ''"%(uploader)s/[%(upload_date>%Y-%m-%d)s] - %(title)s [%(id)s].%(ext)s"'';

      sponsorblock-remove = "default";

      sub-format = "srt";
      sub-langs = "en";
    };

    # `settings` doesn't support multi-passed flags
    extraConfig = ''
      --paths "home:/srv/videos/"
      --paths "temp:/tmp/yt-dlp"
    '';
  };
}
