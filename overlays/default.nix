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

  fetchFromCratesIo = callOverlay ./fetchFromCratesIo.nix;

  darkman = callOverlay ./darkman.nix;

  eww-wayland = callOverlay ./eww-wayland.nix;

  shairport-sync = callOverlay ./shairport-sync.nix;

  rofi-wayland-unwrapped = callOverlay ./rofi-wayland.nix;
  rofi = final.rofi-wayland;

  sunshine = callOverlay ./sunshine.nix;

  freetube = callOverlay ./freetube.nix;

  maintainers = prev.maintainers // maintainers;

  swww = callOverlay ./swww.nix;

  atuin = callOverlay ./atuin.nix;

  # No release in over 2 years, with many many commits since :ferrisPensive:
  beets = prev.beets-unstable;

  jujutsu = callOverlay ./jujutsu.nix;

  tmux = pkgs-unstable.tmux;
} // import ../packages { pkgs = final; }
