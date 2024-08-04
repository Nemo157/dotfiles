{ lib, pkgs, ... }: {
  imports = [
    ./atuin.nix
    ./bat
    ./dircolors.nix
    ./gpg.nix
    ./lsd.nix
    ./ssh.nix
    ./ssh-agent.nix
    ./starship.nix
    ./tmux.nix
    ./vim
    ./vifm.nix
    ./zsh.nix
  ];

  home.packages = with pkgs; [
    agenix
    cbor-diag-rs
    colmena
    comma
    fd
    htop-vim
    jq
    moreutils
    nix-index
    pstree
    ripgrep
    systemfd
    zebra
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
      cd "$(mktemp --tmpdir -d "scratch.''${1+$1.}$(date +%Y-%m-%dT%H-%M).XXXXXX")"
      export SCRATCH=$PWD
      ln -s ~/.editorconfig .
      if [[ $# -gt 0 ]]
      then
        exec dev "$1"
      else
        exec zsh
      fi
    '';

    "nix-show-build".text = ''
      readarray -t dirs < <(nix build --print-build-logs  --no-link --print-out-paths "$@")
      for dir in "''${dirs[@]}"
      do
        echo
        echo "$dir"
        echo
        ${lib.getExe pkgs.lsd} --tree "$dir"
      done
    '';
  };
}
