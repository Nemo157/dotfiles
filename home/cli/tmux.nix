{ lib, config, pkgs, ... }: {
  programs.tmux = {
    enable = true;
    escapeTime = 0;
    historyLimit = 5000;
    keyMode = "vi";
    extraConfig = ''
      # force a reload of the config file
      unbind r
      bind r source-file ~/.config/tmux/tmux.conf

      set -g display-time 3000

      set -g update-environment "DISPLAY WAYLAND_DISPLAY SWAYSOCK SSH_AUTH_SOCK"

      # Based on https://evertpot.com/osx-tmux-vim-copy-paste-clipboard/

      unbind-key -T copy-mode-vi Enter
      bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'pbcopy'
      bind-key -T copy-mode-vi v send-keys -X begin-selection

      bind-key ] run 'pbpaste | tmux load-buffer - && tmux paste-buffer'

      bind-key 'C-n' next-window
      bind-key 'C-p' previous-window

      bind-key h select-pane -L
      bind-key l select-pane -R
      bind-key k select-pane -U
      bind-key j select-pane -D

      set -g pane-border-format ' #P #T '
      set -g pane-border-style 'fg=cyan'
      set -g pane-active-border-style 'fg=magenta'

      set -g display-panes-active-colour magenta
      set -g display-panes-colour cyan

      set -g status on

      set -g status-interval 5
      set -g status-position top

      set -g status-left-length 30
      set -g status-right-length 150

      set -g status-left '#[bg=black]'
      set -ag status-left '#[fg=blue] #h '
      set -ag status-left '#[fg=magenta] #S '
      set -ag status-left '#[fg=terminal bg=terminal] · '

      set -g status-right ""
      set -ag status-right '#[fg=terminal bg=terminal] · '
      set -ag status-right '#[bg=black]'
      set -ag status-right "#[fg=terminal]#(date '+  %Y-%m-%d %H:%M:%S') "

      set -g status-justify left

      set -g status-style 'fg=white bg=terminal'
      set -g window-status-style 'fg=terminal bg=black'

      set -g window-status-bell-style 'fg=red bg=black'
      set -g window-status-last-style 'fg=terminal bg=black'
      set -g window-status-current-style 'fg=magenta bg=black'

      set -g window-status-current-format ' #I #W '
      set -g window-status-format ' #I #W '

      set -g message-style 'fg=white bg=black'

      setw -g clock-mode-colour green

      set -g default-terminal tmux-256color

      bind-key u run-shell -C { capture-pane -S '#{?#{==:#{pane_mode},copy-mode},-#{scroll_position},0}' -E '#{?#{==:#{pane_mode},copy-mode},#{e|-:#{pane_height},#{scroll_position}},#{pane_height}}' }\; save-buffer /tmp/tmux-buffer \; new-window 'urlview /tmp/tmux-buffer'
    '';
  };
}
