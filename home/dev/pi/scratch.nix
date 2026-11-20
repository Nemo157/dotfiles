# Scratch pi session in a modal floating tmux pane (prefix + a).
#
# The pane runs a fresh pi in a dedicated state dir and continues the most
# recent session there (`-c`), so the conversation survives closing the
# pane; `/new` starts a fresh one that later scratch panes pick up instead. Quit
# with ctrl+c twice or `/quit` (ctrl+d is rebound, see default.nix).
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
    # modal like a popup, but a real pane so copy mode works; no -D/-C as
    # pi uses Escape and an accidental close would kill a running turn
    bind-key a new-pane -O -x 85% -y 85% -X 7% -Y 7% -B heavy -S 'fg=cyan' -T ' pi scratch ' "${lib.getExe tmux-pi-popup}"
  '';
}
