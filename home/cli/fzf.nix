# fzf's default theme uses fixed 256-colour greys tuned for dark terminals, use
# the Base24 ANSI palette indices instead so it follows the terminal theme (see
# ../dev/glamour.nix for the mapping).
{
  programs.fzf = {
    enable = true;
    # atuin owns the shell history/keybindings
    enableBashIntegration = false;
    enableZshIntegration = false;
    enableFishIntegration = false;
    # the 16 colour base theme, overridden by `colors` below
    defaultOptions = [ "--color=16" ];
    colors = {
      fg = "-1";
      bg = "-1";
      "fg+" = "-1";
      # base01, the base theme uses 0 which is the background
      "bg+" = "18";
      gutter = "-1";
      hl = "2";
      "hl+" = "2";
      border = "8";
      preview-border = "8";
      separator = "19";
      scrollbar = "8";
      label = "7";
      preview-label = "7";
      header = "-1";
      info = "8";
      pointer = "4";
      marker = "5";
      spinner = "2";
    };
  };
}
