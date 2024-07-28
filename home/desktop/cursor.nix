{ config, pkgs, ... }: {
  home.pointerCursor = {
    package = pkgs.catppuccin-cursors.latteRosewater;
    name = "catppuccin-latte-rosewater-cursors";
    gtk.enable = true;
    x11.enable = true;
  };

  # For flatpak apps to access cursors they need to be in ~/.local/share
  # Unfortunately this just creates symlinks the flatpaks can't access, you
  # still need an override added to access the nix store:
  #     flatpak override -u --filesystem /nix/store:ro
  xdg.dataFile = with config.home.pointerCursor; {
    "icons/${name}".source = "${package}/share/icons/${name}";
  };
}
