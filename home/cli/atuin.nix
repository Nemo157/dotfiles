{ lib, pkgs, config, ts, ... }: {
  programs.atuin = {
    enable = true;
    flags = [
      "--disable-up-arrow"
      "--disable-ctrl-r"
    ];
    settings = {
      sync_address = "http://${ts.hosts.mithril.host}:8888";
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
      daemon = {
        enabled = true;
        sync_frequency = 30;
        socket_path = "/run/user/1000/atuin.socket";
        systemd_socket = true;
      };
    };
  };

  programs.zsh.initExtra = lib.mkAfter ''
    if [[ $options[zle] = on ]]; then
      bindkey -a / atuin-search-viins
      bindkey -a k atuin-up-search-vicmd
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

  systemd.user.services.atuin-daemon = {
    Unit = {
      Description = "atuin shell history daemon";
      Requires = [ "atuin-daemon.socket" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.atuin} daemon";
      Environment = [ "ATUIN_LOG=info" ];
    };
    Install = {
      Also = [ "atuin-daemon.socket" ];
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.sockets.atuin-daemon = {
    Unit = {
      Description = "Unix socket activation for atuin shell history daemon";
    };

    Socket = {
      ListenStream = "%t/atuin.socket";
      SocketMode = "0600";
      RemoveOnStop = true;
    };

    Install = {
      WantedBy = [ "sockets.target" ];
    };
  };
}
