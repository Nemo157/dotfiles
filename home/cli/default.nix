{ pkgs, ... }: {
  imports = [
    ./atuin.nix
    ./bat
    ./cargo.nix
    ./git
    ./gh.nix
    ./gpg.nix
    ./lsd.nix
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

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
