{ pkgs, ... }: {
  imports = [
    ./firefox.nix
    ./fonts.nix
    ./kitty.nix
  ];

  home.packages = [
    pkgs.obsidian
  ];
}
