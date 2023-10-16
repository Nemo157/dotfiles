{ config, ... }: {
  xdg.userDirs = {
    enable = true;
    music = "${config.home.homeDirectory}/Music/Library";
  };
  xdg.systemDirs.data = [
    # shouldn't this be in there already?
    config.xdg.dataHome
    "${config.xdg.dataHome}/flatpak/exports/share"
  ];
}
