{ config, pkgs, ... }: {
  programs.git = {
    signing = {
      key = null;
      signByDefault = true;
    };
    settings = {
      user = {
        email = "wim.looman@veecle.io";
        name = "Wim Looman";
      };
      github.user = "Nemo157";
    };
  };
}
