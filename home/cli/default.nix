{ pkgs, ... }: {
  imports = [
    ./bat
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
    cargo-dl
    fd
    htop
    jq
    pstree
    ripgrep
    rust-bin.nightly.latest.cargo
    rust-bin.nightly.latest.rustc
    rustfmt
  ];
}
