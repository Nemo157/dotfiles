{ lib, pkgs, ... }: {
  imports = [
    ./atuin.nix
    ./bat
    ./dircolors.nix
    ./gpg.nix
    ./lsd.nix
    ./ssh.nix
    ./ssh-agent.nix
    ./starship
    ./tmux.nix
    ./vim
    ./vifm.nix
    ./zsh.nix
  ];

  home.packages = with pkgs; [
    cbor-diag-rs
    comma
    dogdns
    fd
    gping
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

  programs.md-tui = {
    enable = true;
    settings = {
      code_bg_color = "black";
      code_block_bg_color = "black";
    };
  };

  programs.git.ignores = [
    ".envrc"
    ".env"
    ".direnv/"
  ];

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

    miniserve-archive = {
      runtimeInputs = with pkgs; [ archivemount coreutils miniserve ];
      text = ''
        trap exit SIGINT

        archive="''${1:-missing archive path}"
        shift
        dir="$(mktemp --tmpdir -d "miniserve-archive.XXXXXX")"

        archivemount -o readonly "$archive" "$dir"

        cleanup() {
          fusermount -u "$dir"
          rmdir "$dir"
        }

        trap cleanup EXIT

        miniserve -i ::1 --index index.html "$dir" "$@"
      '';
    };
  };
}
