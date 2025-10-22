let
  nemo157-mithril = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINaQ3qjviiCKZDmJvQ6L/LF9F/S1SRzIS009floRGzG0 nemo157@mithril";
  nemo157-zinc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILml+0+R7rNJkgWBjALiO5gO63yQypkdSBWNMAT1SxQR nemo157@zinc";
  wim-oak = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPeQegyhCB7UkgG4LwcyHbOs9zmBsonfnPQg1HkKZes2 wim@oak";

  mithril = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINuIJQEiQuK0HxfPjk28NUkqJtzNQpv0nwJ55rQK4PKd";
  zinc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMAmICnjg5MYSLmEJ5YWSilEzWwtjAh6+iOFZ/vAAGCo";
  contabo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBap8/dDxDUVLcVn4U/bIGT44kw4Amm54kaRUwxdYEdZ";
  oak = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ0KsxqQllBb1Hy76Lrj52uZaLjqRNRyt60Qdecw8sER";
in {
  "home/chill/music/listenbrainz-token.age".publicKeys = [ nemo157-mithril nemo157-zinc ];
  "home/veecle/aws-credentials.age".publicKeys = [ nemo157-zinc wim-oak ];
  "home/veecle/linear-api-key.age".publicKeys = [ wim-oak ];
  "home/veecle/ssh-config.age".publicKeys = [ nemo157-zinc wim-oak ];
  "home/veecle/known-hosts.age".publicKeys = [ nemo157-zinc wim-oak ];
  "nixos/laptop/wpa_supplicant.conf.age".publicKeys = [ nemo157-zinc wim-oak zinc oak ];
  "nixos/common/services/grafana/admin-password.age".publicKeys = [ wim-oak nemo157-mithril oak mithril ];
  "nixos/mithril/services/restic-b2-key.age".publicKeys = [ mithril ];
  "nixos/mithril/services/restic-b2-password.age".publicKeys = [ mithril ];
  "nixos/zinc/services/restic-b2-key.age".publicKeys = [ zinc ];
  "nixos/zinc/services/restic-b2-password.age".publicKeys = [ zinc ];
}
