{ pkgs-prev, pkgs-final, ... }:

# Support for showing a system tray with dynamic icons
pkgs-prev.eww-wayland.overrideAttrs (eww-final: eww-prev: rec {
  version = "tray-3-dynamic-icons";
  src = pkgs-final.fetchFromGitHub {
    owner = "ralismark";
    repo = "eww";
    rev = "485dd6263df6123d41d04886a53715b037cf7aaf";
    hash = "sha256-+iu16EVM5dcR5F83EEFjCXVZv1jwPgJq/EqG6M78sAw=";
  };
  cargoDeps = eww-prev.cargoDeps.overrideAttrs {
    name = "eww-${version}-vendor.tar.gz";
    inherit src;
    outputHash = "sha256-fUTNlAvhfgqrro+4uKyTwQPtoru9AnBHmy0XcOMUfOI=";
  };
  buildInputs = eww-prev.buildInputs ++ [
    pkgs-final.libdbusmenu-gtk3
  ];
})
