{ pkgs-prev, pkgs-final, ... }:

(pkgs-prev.sunshine.overrideAttrs(final: prev: rec {
  version = "336062d467d5f48ba56d05a523c212f791421108";
  src = pkgs-final.fetchFromGitHub {
    owner = "LizardByte";
    repo = "Sunshine";
    rev = version;
    fetchSubmodules = true;
    hash = "sha256-p2GZNL92QhQMprq/vpAwU0BW0eZGfRK2MwZ9LkBA0xM=";
  };
  separateDebugInfo = true;
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
