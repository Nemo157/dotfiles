{ lib, config, pkgs, ... }: {
  scripts.eww-hypr-info = {
    runtimeInputs = with pkgs; [ hyprland socat jq coreutils ];
    source = ./eww-hypr-info.sh;
  };

  scripts.eww-hypr-focus-window-for-realsiez = {
    runtimeInputs = with pkgs; [ hyprland jq ];
    source = ./eww-hypr-focus-window-for-realsiez.sh;
  };

  scripts.eww-music-queue = {
    runtimeInputs = with pkgs; [ mpc-cli jq playerctl ];
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
    runtimeInputs = with pkgs; [ eww hyprland socat jq ripgrep coreutils ];
    source = ./eww-auto-open-taskbars.sh;
  };
}
