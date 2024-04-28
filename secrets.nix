let
  nemo157-mithril = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINaQ3qjviiCKZDmJvQ6L/LF9F/S1SRzIS009floRGzG0 nemo157@mithril";
  nemo157-zinc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILml+0+R7rNJkgWBjALiO5gO63yQypkdSBWNMAT1SxQR nemo157@zinc";

  mithril = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINuIJQEiQuK0HxfPjk28NUkqJtzNQpv0nwJ55rQK4PKd";
  zinc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMAmICnjg5MYSLmEJ5YWSilEzWwtjAh6+iOFZ/vAAGCo";
  contabo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBap8/dDxDUVLcVn4U/bIGT44kw4Amm54kaRUwxdYEdZ";
in {
  "home/chill/music/listenbrainz-token.age".publicKeys = [ nemo157-mithril nemo157-zinc ];
  "nixos/wlan-psk.age".publicKeys = [ nemo157-zinc ];
  "nixos/mithril/services/grafana-admin-password.age".publicKeys = [ mithril ];
}
