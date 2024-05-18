{ pkgs-prev, pkgs-final, ... }:

(pkgs-prev.sunshine.overrideAttrs(final: prev: rec {
  runtimeDependencies = prev.runtimeDependencies ++ [
    pkgs-final.libglvnd
  ];
  cmakeFlags = prev.cmakeFlags ++ [
    "-DSUNSHINE_ENABLE_TRAY=OFF"
    "-DSUNSHINE_REQUIRE_TRAY=OFF"
    "-DSUNSHINE_ENABLE_X11=OFF"
    "-DSUNSHINE_ENABLE_DRM=OFF"
  ];
})).override {
  cudaSupport = true;
  # https://github.com/NixOS/nixpkgs/pull/235655
  stdenv = pkgs-final.cudaPackages.backendStdenv;
}
