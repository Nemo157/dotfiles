{ pkgs, ... }: {
  imports = [
    ./alacritty.nix
    ./darkman.nix
    ./firefox.nix
    ./fonts.nix
    ./foot.nix
    ./hyprland.nix
    ./i3.nix
    ./mpv.nix
    ./rofi.nix
    ./sway.nix
  ];

  home.keyboard = {
      layout = "us";
      variant = "dvp";
      options = [ "caps:escape" "compose:ralt" ];
  };
}
