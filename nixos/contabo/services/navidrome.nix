{ pkgs, name, ts, config, ... }: {
  services.navidrome = {
    enable = true;
    package = pkgs.unstable.navidrome; # workaround <https://github.com/NixOS/nixpkgs/issues/481611>
    settings = {
      MusicFolder = "/var/lib/syncthing/music-low";
      EnableSharing = true;
      BaseUrl = "https://music.nemo157.com/";
      SubsonicArtistParticipations = true;
    };
  };

  users.users.${config.services.navidrome.user}.extraGroups = [ "syncthing" ];
}
