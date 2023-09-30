{ lib, config, pkgs, ... }: {
  xdg.configFile."eww/eww.scss" = {
    source = ./eww.scss;
  };

  xdg.configFile."eww/eww.yuck" = {
    source = ./eww.yuck;
  };

  xdg.dataFile."eww/no-album.png" = {
    source = pkgs.requireFile {
      name = "Generic-icon.png";
      url = "https://icons.iconarchive.com/icons/musett/cds/256/Generic-icon.png";
      sha256 = "CoOMVEYnZPTBAZcpD7N0XA5z4yNfOCe5EGBMF7zcViY=";
    };
  };
}
