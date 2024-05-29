{ pkgs, ... }: {
  imports = [
    ./ssh.nix
  ];

  home.packages = with pkgs; [
    element-desktop
    xdg-utils
  ];
}
