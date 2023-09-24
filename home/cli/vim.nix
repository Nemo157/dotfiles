{ config, pkgs, ... }: {
  home.sessionVariables = {
    EDITOR = "vim";
  };

  programs.vim = {
    enable = true;
  };
}
