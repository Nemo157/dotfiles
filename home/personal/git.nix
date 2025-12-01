{ config, pkgs, ... }: {
  programs.git.settings = {
    user = {
      email = "git@nemo157.com";
      name = "Wim Looman";
    };
    github.user = "Nemo157";
  };
}
