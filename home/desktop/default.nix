{ pkgs, ... }: {
  imports = [
    ./alacritty.nix
    ./darkman.nix
    ./eww.nix
    ./firefox.nix
    ./fonts.nix
    ./foot.nix
    ./hyprland.nix
    ./i3.nix
    ./mpv.nix
    ./portal.nix
    ./rofi.nix
    ./sway.nix
  ];

  home.keyboard = {
      layout = "us";
      variant = "dvp";
      options = [ "caps:escape" "compose:ralt" ];
  };
}
