{ pkgs, ... }: {
  imports = [
    ./alacritty.nix
    ./darkman.nix
    ./eww.nix
    ./firefox.nix
    ./fonts.nix
    ./hyprland.nix
    ./mpv.nix
    ./portal.nix
    ./rofi.nix
  ];

  home.keyboard = {
      layout = "us";
      variant = "dvp";
      options = [ "caps:escape" "compose:ralt" ];
  };
}
