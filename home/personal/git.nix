{ config, pkgs, ... }: {
  programs.git = {
    signing = {
      key = null;
      signByDefault = true;
    };
    userEmail = "git@nemo157.com";
    userName = "Wim Looman";
    extraConfig.github.user = "Nemo157";
  };
}
