{ pkgs-final, pkgs-prev, ... }:

pkgs-prev.rofi-wayland-unwrapped.overrideAttrs (final: prev: rec {
  version = "54464992eb11eda1f19829d04e492e3360b77d66";
  src = pkgs-final.fetchFromGitHub {
    owner = "Nemo157";
    repo = "rofi";
    rev = version;
    fetchSubmodules = true;
    sha256 = "sha256-MllsDYN2eyi0h+Nsxi38E9fPb1bSJ4Y7MaTDbB1gF7Y=";
  };
})
