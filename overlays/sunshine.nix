{ pkgs-prev, pkgs-final, ... }:

(pkgs-prev.sunshine.overrideAttrs(final: prev: rec {
  cmakeFlags = prev.cmakeFlags ++ [
    "-DSUNSHINE_ENABLE_TRAY=OFF"
    "-DSUNSHINE_REQUIRE_TRAY=OFF"
    "-DSUNSHINE_ENABLE_X11=OFF"
    "-DSUNSHINE_ENABLE_DRM=OFF"
  ];
})).override {
  cudaSupport = true;
}
