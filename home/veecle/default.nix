{ pkgs, ... }: {
  imports = [
    ./claude
    ./ssh.nix
    ./git.nix
    ./jujutsu.nix
    ./aws.nix
    ./linear.nix
  ];

  home.packages = with pkgs; [
    element-desktop
    xdg-utils
    slack
  ];
}
