{ lib, config, pkgs, ... }: {
  imports = [
    ./colors.nix
    ./cross-machine.nix
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

      draw_bold_text_with_bright_colors = false;

      mouse = {
        double_click.threshold = 300;
        triple_click.threshold = 300;
        hide_when_typing = true;
      };

      hints.url = {
        launcher = "open";
        modifiers = "Command";
      };

      selection.semantic_escape_chars = ",│`|:\"' ()[]{}<>";

      shell = {
        program = "zsh";
        args = [
          "--login"
          "-c"
          "tmux -u new-session -s master-$(hostname -s) -t master -A"
        ];
      };
    };
  };
}
