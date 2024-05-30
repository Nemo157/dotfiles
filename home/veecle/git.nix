{ config, pkgs, ... }: {
  programs.git = {
    signing = {
      key = null;
      signByDefault = true;
    };
    userEmail = "wim.looman@veecle.io";
    userName = "Wim Looman";
    extraConfig.github.user = "Nemo157";
  };
}
