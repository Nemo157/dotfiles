{ name, ts, config, ... }: {
  services.navidrome = {
    enable = true;
    settings = {
      MusicFolder = "/var/lib/syncthing/music-low";
      EnableSharing = true;
      BaseUrl = "https://music.nemo157.com/";
      SubsonicArtistParticipations = true;
    };
  };

  users.users.${config.services.navidrome.user}.extraGroups = [ "syncthing" ];
}
