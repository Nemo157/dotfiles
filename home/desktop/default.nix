{ pkgs, ... }: {
  imports = [
    ./alacritty
    ./firefox.nix
    ./fonts.nix
    ./kitty.nix
    ./wezterm.nix
  ];

  home.packages = [
    pkgs.obsidian
  ];
}
