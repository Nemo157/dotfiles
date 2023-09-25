{ config, pkgs, ... }: {
  programs.bat = {
    enable = true;

    config = {
      theme = "eink2";
    };
    themes = {
      eink2 = builtins.readFile ./eink2.tmTheme;
    };
  };
}
