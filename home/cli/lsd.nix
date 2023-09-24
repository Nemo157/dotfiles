{ config, pkgs, ... }: {
  programs.lsd = {
    enable = true;
    enableAliases = true;

    settings = {
      blocks = [
        "permission"
        "user"
        "group"
        "size"
        "date"
        "git"
        "name"
      ];

      color = {
        when = "auto";
        theme = "colors.yaml";
      };

      date = "relative";
      dereference = false;
      indicators = true;
      total-size = true;
    };
  };

  # TODO: use https://github.com/nix-community/home-manager/commit/835465e8ba2459034e4ab192b1c6db35d1c0d638
  xdg.configFile."lsd/themes/colors.yaml" = {
    source = (pkgs.formats.yaml {}).generate "lsd-colors" {
      user = 10;
      group = 10;
      permission = {
        read = "dark_green";
        write = "dark_yellow";
        exec = "dark_red";
        exec-sticky = "dark_magenta";
        no-access = "dark_magenta";
        octal = 10;
        acl = "dark_cyan";
        context = "dark_cyan";
      };
      date = {
        hour-old = "green";
        day-old = "yellow";
        older = "blue";
      };
      size = {
        none = 10;
        small = "dark_green";
        medium = "dark_yellow";
        large = "dark_red";
      };
      inode = {
        valid = "dark_green";
        invalid = "dark_red";
      };
      links = {
        valid = "dark_cyan";
        invalid = "dark_magenta";
      };
      tree-edge = 10;
      # git-status = {
      #   default = 10;
      #   unmodified = 10;
      #   ignored = "white";
      #   new-in-index = "dark_green";
      #   new-in-workdir = "dark_green";
      #   typechange = "dark_yellow";
      #   deleted = "dark_red";
      #   renamed = "dark_green";
      #   modified = "dark_yellow";
      #   conflicted = "dark_red";
      # };
    };
  };
}
