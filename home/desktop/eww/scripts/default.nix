{ lib, config, pkgs, pkgs-unstable, ... }: {
  scripts.eww-hypr-workspaces = {
    runtimeInputs = [ pkgs.hyprland pkgs.socat pkgs.jq pkgs.coreutils ];
    source = ./eww-hypr-workspaces;
  };

  scripts.eww-color-scheme = {
    runtimeInputs = [ pkgs.jq pkgs.systemd ];
    source = ./eww-color-scheme;
  };

  scripts.eww-music-queue = {
    runtimeInputs = [ pkgs.mpc-cli pkgs.jq pkgs.playerctl ];
    source = ./eww-music-queue;
  };

  scripts.eww-music-status = {
    runtimeInputs = [ pkgs.jq pkgs.playerctl ];
    source = ./eww-music-status;
  };

  scripts.eww-music-metadata = {
    runtimeInputs = [ pkgs.jq pkgs.playerctl ];
    source = ./eww-music-metadata;
  };
}
