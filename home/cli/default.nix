{ pkgs, ... }: {
  imports = [
    ./bat
    ./git
    ./gpg.nix
    ./lsd.nix
    ./starship.nix
    ./tmux.nix
    ./vim
    ./zsh.nix
  ];

  home.packages = with pkgs; [
    fd
    htop
    pstree
    ripgrep
  ];
}
