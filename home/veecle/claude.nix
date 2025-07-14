{ lib, pkgs, ... }:
let
  # TODO: claude-code config management is all kinds of fucked, it's both a config dir and a state
  # dir so must be read-write, but it doesn't follow symlinks in it, so I can't trivially generate a
  # symlink tree like CARGO_HOME.
  #
  # For now put up with the invasion of `~/.claude` and `~/.claude.json`.
  #
  # # TODO: json writer
  # settings-json = pkgs.writeText "claude-code-settings.json" ''
  #   {
  #     "includeCoAuthoredBy": false,
  #     "env": {
  #       "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
  #       "DISABLE_AUTOUPDATER": "1",
  #       "DISABLE_BUG_COMMAND": "1",
  #       "DISABLE_ERROR_REPORTING": "1",
  #       "DISABLE_TELEMETRY": "1"
  #     }
  #   }
  # '';
  #
  # # Claude Code is buggy about loading symlinks, so the config files all need to be copied.
  # config-dir = pkgs.runCommand "claude-code-config-dir" {} ''
  #   mkdir $out
  #   cp ${settings-json} $out/settings.json
  # '';
  #
  # makeWrapper "${lib.getExe unwrapped}" $out/bin/claude --set CLAUDE_CONFIG_DIR ${config-dir}

  unwrapped = pkgs.unstable.claude-code;

  claude-code = pkgs.runCommand unwrapped.name {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } ''
    makeWrapper "${lib.getExe unwrapped}" $out/bin/claude \
      --set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1 \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_BUG_COMMAND 1 \
      --set DISABLE_ERROR_REPORTING 1 \
      --set DISABLE_TELEMETRY 1
  '';
in {
  home.packages = [ claude-code ];

  # Run a claude instance in a fresh workspace
  scripts.jj-claude = {
    runtimeInputs = [ pkgs.coreutils pkgs.jujutsu claude-code ];
    source = ./jj-claude.sh;
  };

  programs.jujutsu.settings.aliases.claude = ["util" "exec" "--" "jj-claude"];
}
