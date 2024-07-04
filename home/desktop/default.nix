{ pkgs, ... }: {
  imports = [
    ./alacritty
    ./cursor.nix
    ./darkman.nix
    ./eww
    ./firefox.nix
    ./fonts.nix
    ./hyprland.nix
    ./mako.nix
    ./mpv.nix
    ./portal.nix
    ./rofi.nix
    ./wallpaper
    ./wezterm.nix
  ];

  home.packages = with pkgs; [
    wl-clipboard
    obsidian
  ];

  home.keyboard = {
      layout = "us";
      variant = "dvp";
      options = [ "caps:escape" "compose:ralt" ];
  };

  services.u2f-touch-detector.enable = true;

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = [ "firefox.desktop" ];
      "x-scheme-handler/https" = [ "firefox.desktop" ];
      "x-scheme-handler/file" = [ "firefox.desktop" ];
    };
  };
}
