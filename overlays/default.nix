{ pkgs-unstable, pkgs-hyprland, maintainers }: final: prev: let
  args = {
    inherit pkgs-unstable;
    # nix flake check doesn't like me renaming the function arguments,
    # so we have to alias here....
    pkgs-final = final;
    pkgs-prev = prev;
  };
  intersectAttrs = builtins.intersectAttrs;
  functionArgs = builtins.functionArgs;
  callOverlay = path: (import path) args;
in {
  inherit (pkgs-unstable)
    tmux cargo-deny swww obsidian
    atuin shairport-sync;
  inherit (pkgs-hyprland) hyprland hyprcursor hyprlock;

  # https://github.com/hyprwm/hypridle/issues/83
  hypridle = pkgs-hyprland.hypridle.overrideAttrs { patches = [ ./hypridle-flush-logs.patch ]; };

  darkman = callOverlay ./darkman.nix;

  rofi-wayland-unwrapped = callOverlay ./rofi-wayland.nix;
  rofi = final.rofi-wayland;

  sunshine = callOverlay ./sunshine.nix;

  freetube = callOverlay ./freetube.nix;

  maintainers = prev.maintainers // maintainers;

  # No release in over 2 years, with many many commits since :ferrisPensive:
  beets = prev.beets-unstable;

  jujutsu = callOverlay ./jujutsu.nix;

  # broken with 1.80 changes
  # starship = callOverlay ./starship.nix;

  u2f-touch-detector = prev.u2f-touch-detector.override {
    rustPlatform = pkgs-unstable.rustPlatform;
  };

  unstable = pkgs-unstable;
} // import ../packages { pkgs = final; }
