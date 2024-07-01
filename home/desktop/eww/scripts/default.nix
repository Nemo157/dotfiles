{ lib, config, pkgs, ... }: {
  scripts.eww-hypr-info = {
    runtimeInputs = [ pkgs.hyprland pkgs.socat pkgs.jq pkgs.coreutils ];
    source = ./eww-hypr-info.sh;
  };

  scripts.eww-hypr-focus-window-for-realsiez = {
    runtimeInputs = [ pkgs.hyprland pkgs.jq ];
    source = ./eww-hypr-focus-window-for-realsiez.sh;
  };

  scripts.eww-color-scheme = {
    runtimeInputs = [ pkgs.jq pkgs.systemd ];
    source = ./eww-color-scheme.sh;
  };

  scripts.eww-music-queue = {
    runtimeInputs = [ pkgs.mpc-cli pkgs.jq pkgs.playerctl ];
    source = ./eww-music-queue.sh;
  };

  scripts.eww-music-status = {
    runtimeInputs = [ pkgs.jq pkgs.playerctl ];
    source = ./eww-music-status.sh;
  };

  scripts.eww-music-metadata = {
    runtimeInputs = [ pkgs.jq pkgs.playerctl ];
    source = ./eww-music-metadata.sh;
  };

  scripts.eww-u2f-touch-detector = {
    runtimeInputs = [ pkgs.socat ];
    source = ./eww-u2f-touch-detector.sh;
  };

  scripts.eww-auto-open-taskbars = {
    runtimeInputs = [ pkgs.eww pkgs.hyprland pkgs.socat pkgs.jq ];
    source = ./eww-auto-open-taskbars.sh;
  };
}
