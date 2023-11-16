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

  scripts = {
    "dev".text = ''
      exec nix develop pkgs#"$1" --command zsh
    '';

    "scratch".text = ''
      cd "$(mktemp -d)"
      export SCRATCH=$PWD
      if [[ $# -gt 0 ]]
      then
        exec dev "$1"
      else
        exec zsh
      fi
    '';
  };
}
