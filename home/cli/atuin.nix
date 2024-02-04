{ lib, config, ts, ... }: {
  programs.atuin = {
    enable = true;
    flags = [
      "--disable-up-arrow"
      "--disable-ctrl-r"
    ];
    settings = {
      sync_frequency = 0;
      sync_address = "http://${ts.mithril.host}:8888";
      history_filter = [
        "^ "
      ];
      workspaces = true;
      update_check = false;
      style = "compact";
      inline_height = 20;
      show_preview = true;
      search_mode = "prefix";
      keymap_mode = "auto";
    };
  };

  programs.zsh.initExtra = lib.mkAfter ''
    if [[ $options[zle] = on ]]; then
      bindkey -a / _atuin_search_viins_widget
      bindkey -a k _atuin_up_search_vicmd_widget
    fi

    # Add --cwd flag to have auto-workspace-detection active
    _zsh_autosuggest_strategy_atuin_auto() {
        suggestion=$(atuin search --cwd . --cmd-only --limit 1 --search-mode prefix -- "$1")
    }

    _zsh_autosuggest_strategy_atuin_global() {
        suggestion=$(atuin search --cmd-only --limit 1 --search-mode prefix -- "$1")
    }

    ZSH_AUTOSUGGEST_STRATEGY=(atuin_auto atuin_global)
  '';

  programs.zsh.profileExtra = ''
    # Workaround sqlite/zfs bugs by storing sqlite databases on a tmpfs
    # https://github.com/atuinsh/atuin/issues/952
    if ! [ -e "$XDG_RUNTIME_DIR/atuin" ]
    then
      mkdir -p "${config.xdg.dataHome}/atuin-permanent"
      mkdir -p "$XDG_RUNTIME_DIR/atuin"
      ln -s "${config.xdg.dataHome}"/atuin-permanent/{host-id,key,session} "$XDG_RUNTIME_DIR/atuin/"
      ln -s "$XDG_RUNTIME_DIR/atuin" ~/.local/share/atuin
      atuin sync --force
    fi
  '';
}
