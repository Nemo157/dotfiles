{ pkgs, ... }: {
  imports = [
    ./bat
    ./git
    ./gpg.nix
    ./lsd.nix
    ./starship.nix
    ./tmux.nix
    ./vim.nix
    ./zsh.nix
  ];

  home.packages = with pkgs; [
    fd
    htop
    pstree
    ripgrep
  ];
}
