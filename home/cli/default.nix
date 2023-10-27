{ pkgs, ... }: {
  imports = [
    ./atuin.nix
    ./bat
    ./git
    ./gh.nix
    ./gpg.nix
    ./lsd.nix
    ./rust
    ./ssh.nix
    ./ssh-agent.nix
    ./starship.nix
    ./tmux.nix
    ./vim
    ./zsh.nix
  ];

  home.packages = with pkgs; [
    agenix
    comma
    fd
    gcc
    htop
    jq
    moreutils
    nix-index
    pstree
    ripgrep
    systemfd
  ];
}
