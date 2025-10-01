{ pkgs, ... }: {
  imports = [
    ./claude
    ./ssh.nix
    ./git.nix
    ./jujutsu.nix
    ./aws.nix
  ];

  home.packages = with pkgs; [
    element-desktop
    xdg-utils
    slack
  ];
}
