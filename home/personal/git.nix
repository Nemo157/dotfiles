{ config, pkgs, ... }: {
  programs.git = {
    userEmail = "git@nemo157.com";
    userName = "Wim Looman";
    extraConfig.github.user = "Nemo157";
  };
}
