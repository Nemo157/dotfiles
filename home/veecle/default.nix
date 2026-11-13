{ pkgs, ... }: {
  imports = [
    ./claude
    ./opencode
    ./pi.nix
    ./ssh.nix
    ./git.nix
    ./jujutsu.nix
    ./aws.nix
    ./slack.nix
  ];

  home.packages = with pkgs; [
    element-desktop
    xdg-utils
  ];
}
