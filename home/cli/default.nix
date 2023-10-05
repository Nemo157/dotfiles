{ pkgs, ... }: {
  imports = [
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
    fd
    htop
    jq
    pstree
    ripgrep
    gcc
    systemfd
  ];
}
