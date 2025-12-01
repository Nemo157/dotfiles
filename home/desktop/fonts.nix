{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    nerd-fonts.fira-code
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    # some kind of post-update build issues, investigate later
    # ferris-icons
  ];
  fonts.fontconfig.enable = true;
}
