{ config, pkgs, ... }: {
  home.pointerCursor = {
    package = pkgs.catppuccin-cursors.latteLight;
    name = "catppuccin-latte-light-cursors";
    gtk.enable = true;
    x11.enable = true;
  };

  xdg.dataFile = {
    # For flatpak apps to access cursors they need to be in ~/.local/share
    # Unfortunately this just creates symlinks the flatpaks can't access, you
    # still need an override added to access the nix store:
    #     flatpak override -u --filesystem /nix/store:ro
    "icons/catppuccin-latte-light-cursors".source = "${pkgs.catppuccin-cursors.latteLight}/share/icons/catppuccin-latte-light-cursors";
    "icons/catppuccin-mocha-dark-cursors".source = "${pkgs.catppuccin-cursors.mochaDark}/share/icons/catppuccin-mocha-dark-cursors";

    "light-mode.d/hyprcursor-light.sh" = {
      source = pkgs.writeShellScript "hyprcursor-light.sh" ''
        ${pkgs.hyprland}/bin/hyprctl setcursor catppuccin-mocha-dark-cursors 32
      '';
    };

    "dark-mode.d/hyprcursor-dark.sh" = {
      source = pkgs.writeShellScript "hyprcursor-dark.sh" ''
        ${pkgs.hyprland}/bin/hyprctl setcursor catppuccin-latte-light-cursors 32
      '';
    };
  };
}
