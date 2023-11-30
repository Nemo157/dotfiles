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

  # for mullvad exit-node support
  tailscale = pkgs-unstable.tailscale;

  atuin = pkgs-unstable.atuin;

  alacritty = pkgs-unstable.alacritty;
  cargo-vet = pkgs-unstable.cargo-vet;
  cargo-audit = pkgs-unstable.cargo-audit;
  cargo-semver-checks = pkgs-unstable.cargo-semver-checks;
  sqlx-cli = pkgs-unstable.sqlx-cli;

  darkman = callOverlay ./darkman.nix;

  eww-wayland = callOverlay ./eww-wayland.nix;

  shairport-sync = callOverlay ./shairport-sync.nix;

  rofi-wayland-unwrapped = callOverlay ./rofi-wayland.nix;
  rofi-unwrapped = final.rofi-wayland-unwrapped;

  freetube = callOverlay ./freetube.nix;

  maintainers = prev.maintainers // maintainers;

} // import ../packages { pkgs = final; }
