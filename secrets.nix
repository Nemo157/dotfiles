let
  mithril = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINaQ3qjviiCKZDmJvQ6L/LF9F/S1SRzIS009floRGzG0 nemo157@mithril";
in {
  "home/chill/music/listenbrainz-token.age".publicKeys = [ mithril ];
}
