{ pkgs-final, pkgs-unstable, ... }:

pkgs-unstable.rofi-wayland-unwrapped.overrideAttrs (final: prev: rec {
  version = "f7fcb4c5a08e40846bfd5298ecc0de264e1eedb8";
  src = pkgs-final.fetchFromGitHub {
    owner = "Nemo157";
    repo = "rofi";
    rev = version;
    fetchSubmodules = true;
    sha256 = "sha256-B7ljMbqV0Jw8nyChjlytoBCNdEqBSS2TudZv1yOa6/k=";
  };
})
