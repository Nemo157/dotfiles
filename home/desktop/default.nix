{ pkgs, ... }: {
  imports = [
    ./alacritty.nix
    ./darkman.nix
    ./eww
    ./firefox.nix
    ./fonts.nix
    ./hyprland.nix
    ./mpv.nix
    ./portal.nix
    ./rofi.nix
  ];

  home.packages = [
    pkgs.wl-clipboard
  ];

  home.keyboard = {
      layout = "us";
      variant = "dvp";
      options = [ "caps:escape" "compose:ralt" ];
  };
}
