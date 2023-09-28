{ lib, config, pkgs, pkgs-unstable, ... }: {
  xdg.dataFile."eww/no-album.png" = {
    source = pkgs.requireFile {
      name = "Generic-icon.png";
      url = "https://icons.iconarchive.com/icons/musett/cds/256/Generic-icon.png";
      sha256 = "CoOMVEYnZPTBAZcpD7N0XA5z4yNfOCe5EGBMF7zcViY=";
    };
  };

  programs.eww = {
    enable = true;
    package = pkgs-unstable.eww-wayland;
    configDir = ./eww;
  };
}
