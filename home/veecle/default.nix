{ pkgs, ... }: {
  imports = [
    ./claude.nix
    ./ssh.nix
    ./git.nix
    ./jujutsu.nix
  ];

  home.packages = with pkgs; [
    element-desktop
    xdg-utils
    slack
  ];
}
