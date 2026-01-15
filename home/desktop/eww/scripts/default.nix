{ lib, config, pkgs, ... }: {
  scripts.eww-wm-info = {
    runtimeInputs = with pkgs; [ niri jq coreutils ];
    source = ./eww-wm-info.sh;
  };

  scripts.eww-wm-focus-workspace = {
    runtimeInputs = with pkgs; [ niri ];
    source = ./eww-wm-focus-workspace.sh;
  };

  scripts.eww-wm-close-window = {
    runtimeInputs = with pkgs; [ niri ];
    source = ./eww-wm-close-window.sh;
  };

  scripts.eww-wm-maximize = {
    runtimeInputs = with pkgs; [ niri ];
    source = ./eww-wm-maximize.sh;
  };

  scripts.eww-wm-focus-window = {
    runtimeInputs = with pkgs; [ niri ];
    source = ./eww-wm-focus-window.sh;
  };

  scripts.eww-wm-spawn = {
    runtimeInputs = with pkgs; [ niri ];
    source = ./eww-wm-spawn.sh;
  };

  scripts.eww-music-queue = {
    runtimeInputs = with pkgs; [ mpc jq playerctl ];
    source = ./eww-music-queue.sh;
  };

  scripts.eww-music-status = {
    runtimeInputs = with pkgs; [ jq playerctl ];
    source = ./eww-music-status.sh;
  };

  scripts.eww-music-metadata = {
    runtimeInputs = with pkgs; [ jq playerctl ];
    source = ./eww-music-metadata.sh;
  };

  scripts.eww-u2f-touch-detector = {
    runtimeInputs = with pkgs; [ socat ];
    source = ./eww-u2f-touch-detector.sh;
  };

  scripts.eww-auto-open-taskbars = {
    runtimeInputs = with pkgs; [ eww niri socat jq ripgrep coreutils ];
    source = ./eww-auto-open-taskbars.sh;
  };

  scripts.eww-listenbrainz = {
    runtimeInputs = with pkgs; [ curl jq ];
    source = ./eww-listenbrainz.sh;
  };

  scripts.eww-appearance-watcher = {
    runtimeInputs = with pkgs; [ appearance-watcher coreutils ];
    source = ./eww-appearance-watcher.sh;
  };
}
