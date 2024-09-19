{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    (nerdfonts.override { fonts = ["FiraCode"]; })
    noto-fonts
    noto-fonts-emoji
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    ferris-icons
  ];
  fonts.fontconfig.enable = true;
}
