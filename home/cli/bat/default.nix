{ config, pkgs, ... }: {
  programs.bat = {
    enable = true;

    config = {
      theme = "eink2";
    };
    themes = {
      eink2 = {
        src = ./eink2.tmTheme;
      };
    };
  };
}
