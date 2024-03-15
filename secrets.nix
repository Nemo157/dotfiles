let
  mithril = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINaQ3qjviiCKZDmJvQ6L/LF9F/S1SRzIS009floRGzG0 nemo157@mithril";
  zinc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILml+0+R7rNJkgWBjALiO5gO63yQypkdSBWNMAT1SxQR nemo157@zinc";
in {
  "home/chill/music/listenbrainz-token.age".publicKeys = [ mithril zinc ];
  "nixos/wlan-psk.age".publicKeys = [ zinc ];
  "nixos/mithril/services/grafana-admin-password.age".publicKeys = [ mithril ];
}
