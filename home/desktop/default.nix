{ pkgs, ... }: {
  imports = [
    ./alacritty.nix
    ./cursor.nix
    ./darkman.nix
    ./eww
    ./firefox.nix
    ./fonts.nix
    ./hyprland.nix
    ./mpv.nix
    ./portal.nix
    ./rofi.nix
  ];

  home.packages = with pkgs; [
    wl-clipboard
    urlview
  ];

  home.keyboard = {
      layout = "us";
      variant = "dvp";
      options = [ "caps:escape" "compose:ralt" ];
  };
}
