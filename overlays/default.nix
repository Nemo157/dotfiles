{ pkgs-unstable, maintainers }: final: prev: let
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
    tmux cargo-deny hyprland xdg-desktop-portal-hyprland swww obsidian hyprlock;

  darkman = callOverlay ./darkman.nix;

  shairport-sync = callOverlay ./shairport-sync.nix;

  rofi-wayland-unwrapped = callOverlay ./rofi-wayland.nix;
  rofi = final.rofi-wayland;

  sunshine = callOverlay ./sunshine.nix;

  freetube = callOverlay ./freetube.nix;

  maintainers = prev.maintainers // maintainers;

  # No release in over 2 years, with many many commits since :ferrisPensive:
  beets = prev.beets-unstable;

  jujutsu = callOverlay ./jujutsu.nix;

  starship = callOverlay ./starship.nix;

  u2f-touch-detector = prev.u2f-touch-detector.override {
    rustPlatform = pkgs-unstable.rustPlatform;
  };

  unstable = pkgs-unstable;
} // import ../packages { pkgs = final; }
