{ config, pkgs, ... }: {
  programs.bat = {
    enable = true;

    config = {
      theme = "base24-eink2";
    };
    themes = {
      eink2 = {
        src = ./eink2.tmTheme;
      };
      base24-eink2 = {
        src = ./base24-eink2.tmTheme;
      };
    };
  };
}
