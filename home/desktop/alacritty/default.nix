{ lib, config, pkgs, ... }: {
  imports = [
    ./colors.nix
  ];

  programs.alacritty = {
    enable = true;

    settings = {
      window.padding = { x = 5; y = 0; };

      scrolling.history = 0;

      font = {
        normal.family = "FiraCode Nerd Font";
        size = 11.0;
      };

      bell.duration = 0;

      colors.draw_bold_text_with_bright_colors = false;

      mouse = {
        hide_when_typing = true;
      };

      selection.semantic_escape_chars = ",│`|:\"' ()[]{}<>";

      terminal.shell = {
        program = "zsh";
        args = [
          "--login"
          "-c"
          "tmux -u new-session -s primary-$(hostname -s) -t primary -A"
        ];
      };
    };
  };
}
