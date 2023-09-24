{ lib, config, pkgs, ... }:
let
  sol = (import ../sol.nix);
in {
  programs.foot = {
    enable = true;

    settings = {
      main = {
        shell = "zsh --login -c 'tmux -u new-session -s master-$(hostname -s) -t master -A'";
        font = "FiraCode Nerd Font:size=11";
        word-delimiters = ",│`|:\"' ()[]{}<>";
      };

      scrollback.lines = 0;

      mouse.hide-when-typing = true;

      colors = with sol.nohash; {
          background = base03;
          foreground = base0;

          regular0 = base02;
          regular1 = red;
          regular2 = green;
          regular3 = yellow;
          regular4 = blue;
          regular5 = magenta;
          regular6 = cyan;
          regular7 = base2;

          bright0 = base03;
          bright1 = orange;
          bright2 = base1;
          bright3 = base0;
          bright4 = base00;
          bright5 = violet;
          bright6 = base01;
          bright7 = base3;
      };
    };
  };
}
