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

      app="$(systemd-escape "$1")"
      unit="app-rofi-$app-$RANDOM"
      run exec systemd-run --scope --user --slice-inherit --slice="$app" --unit="$unit" systemd-cat -t "$app" "$@"
    '';
  };
in {
  scripts.rofi-systemd = {
    runtimeInputs = with pkgs; [ systemd ];
    text = ''
      exec systemd-run --scope --user --slice=app --unit="rofi-$RANDOM" systemd-cat -t rofi rofi -show drun -run-command "${lib.getExe run-command} {cmd}"
    '';
  };

  programs.rofi = {
    enable = true;
    extraConfig = {
      modi = "drun,window,run,emoji:rofimoji";
      show-icons = true;
      kb-element-next = "";
      kb-element-prev = "";
      kb-mode-next = "Shift+Right,Tab";
      kb-mode-previous = "Shift+Left";
      kb-row-up = "Up,Control+p";
      kb-row-tab = "";
    };
  };
  home.packages = [ pkgs.rofimoji ];
}
