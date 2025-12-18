{ pkgs, ... }: {
  imports = [
    ./alacritty
    ./cursor.nix
    ./darkman.nix
    ./dunst.nix
    ./eww
    ./firefox.nix
    ./fonts.nix
    ./hypr
    ./kitty.nix
    ./mpv.nix
    ./niri.nix
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

  services.u2f-touch-detector = {
    enable = true;
    settings = {
      notify = {
        enable = true;
        heading = "I can haz touch?";
        message = "";
        image = pkgs.requireFile {
          name = "ferrisPlead.png";
          url = "https://media.discordapp.net/attachments/536629832080162846/857441451444666408/ferrisPlead.png?ex=669b1b94&is=6699ca14&hm=4018ba4f751cf2bc228e17b052af24004bb1e52eb7694a13e0200f0f24c9e75e&format=png";
          sha256 = "1rx5xddh9dz5jp4pnnk6yi20ydyv2k6m5463zh8mx66qznbhrx7k";
        };
      };
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = [ "firefox.desktop" ];
      "x-scheme-handler/https" = [ "firefox.desktop" ];
      "x-scheme-handler/file" = [ "firefox.desktop" ];
    };
  };
}
