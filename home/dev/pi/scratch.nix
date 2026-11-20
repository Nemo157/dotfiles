# Scratch pi session in a single persistent floating tmux pane (prefix + a).
#
# prefix + a floats the pane over the current pane, or stashes it away in the
# `_pi-scratch` session when it is the focused pane, so the same pi keeps
# running across toggles and windows. (A modal pane can't be moved between
# windows, so this is a plain floating pane.)
#
# The pane runs pi in a dedicated state dir and continues the most recent
# session there (`-c`), so the conversation also survives quitting pi;
# `/new` starts a fresh one that later panes pick up instead. Quit with
# ctrl+c twice or `/quit` (ctrl+d is rebound, see default.nix).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  scratchDir = "${config.xdg.stateHome}/pi/scratch";

  json = pkgs.formats.json { };

  # Stable across reopens (a store file passed via `--append-system-prompt`),
  # so reopening the session doesn't churn the provider prompt cache.
  systemPrompt = pkgs.writeText "pi-scratch-system.md" ''
    ## Scratch Session

    This pi runs in a floating tmux pane as a scratch session, opened next to
    whatever the user is working on for quick questions, lookups and side
    tasks. The conversation persists across reopens, so earlier exchanges
    may be unrelated to the current question.

    The working directory (${scratchDir}) is a throwaway scratch area, not
    a project: there is no repository, VCS or flake here. Create, edit and
    delete files in it freely without asking; writes elsewhere still need
    approval. Files the user mentions by absolute path usually live in
    their projects under ~/sources.

    The pane is small: keep answers short and to the point.
  '';

  tmux-pi-popup = pkgs.writeShellApplication {
    name = "tmux-pi-popup";
    runtimeInputs = [ config.programs.pi.finalPackage ];
    text = ''
      mkdir -p ${lib.escapeShellArg scratchDir}
      cd ${lib.escapeShellArg scratchDir}
      # --approve trusts the scratch dir's project config (the relaxed
      # permissions below) without a prompt.
      exec pi --approve --continue \
        --append-system-prompt ${systemPrompt} "$@"
    '';
  };

  tmux-pi-scratch-toggle = pkgs.writeShellApplication {
    name = "tmux-pi-scratch-toggle";
    runtimeInputs = with pkgs; [
      tmux
      coreutils
    ];
    text = ''
      stash=_pi-scratch

      scratch="$(tmux list-panes -a -f '#{@pi-scratch}' -F '#{pane_id}' |
        head -n1)"
      read -r current left top width height < <(tmux display-message -p \
        '#{pane_id} #{pane_left} #{pane_top} #{pane_width} #{pane_height}')

      # focused: stash it in its own window of a hidden session, which keeps
      # a placeholder window so it survives the pane being moved out
      if [[ "$scratch" == "$current" ]]; then
        tmux has-session -t "=$stash" 2>/dev/null ||
          tmux new-session -d -s "$stash" -n stash 'exec sleep infinity'
        tmux break-pane -d -s "$scratch" -t "=$stash:"
        exit
      fi

      # 85% of the current pane, centred on it (sizes include the border)
      w=$((width * 85 / 100))
      h=$((height * 85 / 100))
      x=$((left + (width - w) / 2))
      y=$((top + (height - h) / 2))

      if [[ -z "$scratch" ]]; then
        scratch="$(tmux new-pane -P -F '#{pane_id}' \
          -x "$w" -y "$h" -X "$x" -Y "$y" -B heavy -S 'fg=cyan' \
          -T ' pi scratch ' ${lib.getExe tmux-pi-popup})"
        tmux set-option -p -t "$scratch" @pi-scratch 1
        exit
      fi

      # join-pane can only tile, so tile it into this window then float it;
      # -f splits the whole window so a small current pane still has room.
      # One tmux invocation runs both in one command queue pass, so the
      # intermediate tiled layout is never drawn. The tiled panes still
      # flicker though: the split shrinks them and tmux deliberately sends
      # an apparently no-op resize as two (small, then back 10ms later, see
      # server_client_check_pane_resize) to force a redraw, so TUI apps
      # underneath repaint twice.
      tmux join-pane -d -f -s "$scratch" -t "$current" \; \
        break-pane -W -s "$scratch" -x "$w" -y "$h" -X "$x" -Y "$y"
    '';
  };
in
{
  # Project-scope permission overrides, loaded only for sessions in the
  # scratch dir and merged over the global config in default.nix.
  xdg.stateFile."pi/scratch/.pi/extensions/pi-permission-system/config.json".source =
    json.generate "pi-scratch-permissions.json"
      {
        permission = {
          # Mutating file tools are auto-approved here (bypassing
          # edit-toggle, which only sees `ask`s). Inside the scratch dir that
          # is the point; outside it the write boundary below still asks.
          write = "allow";
          edit = "allow";
          mv = "allow";
          rm = "allow";
          cp = "allow";
          mkdir = "allow";
          cut-lines = "allow";
          paste-lines = "allow";
          replace-block = "allow";
          regex-replace = "allow";

          # A string replaces the global pattern map wholesale (an object
          # would shallow-merge and keep its allow entries, e.g. the cargo
          # source dirs), so every write outside the scratch dir asks.
          # Global `path`/`path_write` rules (secrets, `.pi/`) still apply.
          external_directory_write = "ask";
        };
      };

  programs.tmux.extraConfig = lib.mkAfter ''
    bind-key a run-shell "${lib.getExe tmux-pi-scratch-toggle}"
  '';
}
