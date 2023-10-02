{ pkgs, ... }: {
  imports = [
    ./bat
    ./git
    ./gh.nix
    ./gpg.nix
    ./lsd.nix
    ./starship.nix
    ./tmux.nix
    ./vim
    ./zsh.nix
  ];

  home.packages = with pkgs; [
    cargo
    cargo-dl
    fd
    htop
    jq
    pstree
    ripgrep
    rustc
  ];
}
