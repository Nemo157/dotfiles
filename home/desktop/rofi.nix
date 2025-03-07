{ lib, config, pkgs, ... }:
let
  run-command = pkgs.writeShellApplication {
    name = "run-command";
    text = ''
      run() {
        cmd="$1"
        shift
        printf '\e[34m$ %q' "$cmd" >&2
        printf ' %q' "$@" >&2
        printf '\e[0m\n' >&2
        "$cmd" "$@"
      }

      app="$(systemd-escape "$(filename 1)")"
      unit="app-rofi-$app-$RANDOM"
      run exec systemd-run --scope --user --slice-inherit --slice="$app" --unit="$unit" systemd-cat -t "$app" "$@"
    '';
  };
  rofimoji-modes = [
    "emojis"
    "kaomoji"
    "box_drawing"
    "math"
    "letterlike_symbols"
    "control_pictures"
    "nerd_font"
  ];
  rofimoji-modi = lib.concatStringsSep "," (
    lib.lists.map (mode: "${mode}:rofimoji -f ${mode}") rofimoji-modes
  );
in {
  scripts.rofi-systemd = {
    runtimeInputs = with pkgs; [ systemd ];
    text = ''
      exec systemd-run --scope --user --slice=app --unit="rofi-$RANDOM" systemd-cat -t rofi rofi -show drun -run-command "${lib.getExe run-command} {cmd}"
    '';
  };

  scripts.rofinix = {
    runtimeInputs = [ pkgs.rofi pkgs.nix pkgs.coreutils pkgs.systemd ];
    source = ./rofinix.sh;
  };

  scripts.rofi-characters = {
    runtimeInputs = with pkgs; [ rofi rofimoji coreutils wtype wl-clipboard ];
    text = ''
      wl-copy -c
      rofi -show emojis -modi '${rofimoji-modi}'
      wl-paste -n | wtype -
    '';
  };

  programs.rofi = {
    enable = true;
    extraConfig = {
      modi = "drun,window,nix:rofinix,run";
      show-icons = true;
      kb-element-next = "";
      kb-element-prev = "";
      kb-mode-next = "Shift+Right,Tab";
      kb-mode-previous = "Shift+Left";
      kb-row-up = "Up,Control+p";
      kb-row-tab = "";
    };
  };

  xdg.configFile = {
    "rofimoji.rc".text = ''
      action = copy
      max-recent = 0
    '';
  };
}
