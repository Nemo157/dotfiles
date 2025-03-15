{ lib, pkgs-final, pkgs-unstable, ... }:
let
  freetube = pkgs-unstable.freetube;
in
pkgs-final.symlinkJoin {
  inherit (freetube) name;
  paths = [
    (pkgs-final.writeShellApplication {
      inherit (freetube) name;
      runtimeInputs = [ pkgs-final.gnused ];
      text = ''
        # https://github.com/NixOS/nixpkgs/issues/256401#issuecomment-1734912230
        # and remove some log spam
        ${lib.getExe freetube} "$@" ''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--enable-features=UseOzonePlatform --ozone-platform=wayland}} 2>&1 | sed \
          -e '/Cannot create bo with format/d' \
          -e '/GBM-DRV error (get_bytes_per_component): Unknown or not supported format: 538982482/d'
      '';
    })
    freetube
  ];
}
