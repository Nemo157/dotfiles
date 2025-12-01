{ config, pkgs, ... }: let
  zsh-completion-sync-src = pkgs.fetchFromGitHub {
    owner = "BronzeDeer";
    repo = "zsh-completion-sync";
    rev = "v0.3.0";
    hash = "sha256-zDlmFaKU/Ilzcw6o22Hu9JFt8JKsER8idkb6QrtQKjI=";
  };
in {
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    defaultKeymap = "viins";
    autosuggestion.enable = true;
    enableVteIntegration = true;
    completionInit = ''
      # instead of running compinit here, we need to load this plugin here so that it registers its
      # hooks before autosuggestion's hooks
      source "$HOME/.config/zsh/plugins/zsh-completion-sync/zsh-completion-sync.plugin.zsh"
    '';
    syntaxHighlighting.enable = true;
    cdpath = [
      "${config.home.homeDirectory}"
      "${config.home.homeDirectory}/sources"
    ];
    autocd = true;
    history = {
      extended = true;
      ignoreSpace = true;
      path = "${config.xdg.dataHome}/zsh/zsh_history";
      save = 1000000;
      size = 1000000;
    };
    shellAliases = {
      "cd.." = "cd ..";
      fu = "sudo $( fc -ln -1 )";
      ytop = "ytop -c ansi-8";
    };
    profileExtra = ''
    '';
    initContent = ''
      setopt auto_menu
      setopt correct
      setopt dvorak
      setopt hist_ignore_all_dups
      setopt hist_verify
      setopt inc_append_history
      setopt long_list_jobs
      setopt multios
      setopt prompt_subst

      export GPG_TTY=$(tty)
      export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=14'
      export KEYTIMEOUT=1
      bindkey '^n' autosuggest-accept
      bindkey -M viins '\e\n' self-insert-unmeta
      bindkey -M vicmd '\e\n' self-insert-unmeta

      dir_in_title() {
        if [[ "$TERM" = "tmux"* ]]
        then
          printf "\ek%s\e\\" "''${(%):-%~}"
        fi
      }

      cmd_in_title() {
        if [[ "$TERM" = "tmux"* ]]
        then
          printf "\ek%s %.50s\e\\" "''${(%):-%~}" "$3"
        fi
      }

      chpwd_functions+=(dir_in_title)
      precmd_functions+=(dir_in_title)
      preexec_functions+=(cmd_in_title)
    '';
    plugins = [
      {
        name = "zsh-completion-sync";
        src = zsh-completion-sync-src;
      }
    ];
  };
}
