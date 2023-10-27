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
  callPackage = path: overrides:
    let f = import path;
    in f ((intersectAttrs (functionArgs f) args) // overrides);
in {

  fetchFromCratesIo = callPackage ./fetchFromCratesIo.nix {};

  # for mullvad exit-node support
  tailscale = pkgs-unstable.tailscale;

  atuin = pkgs-unstable.atuin;

  cargo-vet = pkgs-unstable.cargo-vet;

  darkman = callPackage ./darkman.nix {};

  eww-wayland = callPackage ./eww-wayland.nix {};

  shairport-sync = callPackage ./shairport-sync.nix {};

  rofi-wayland-unwrapped = callPackage ./rofi-wayland.nix {};
  rofi-unwrapped = final.rofi-wayland-unwrapped;

  maintainers = prev.maintainers // maintainers;

} // import ../packages { pkgs = final; }
