{ pkgs-final, pkgs-prev, ... }:

# contains a fixed pipewire output module
pkgs-prev.shairport-sync.overrideAttrs(prev: rec {
  version = "4.3.3-dev";
  src = pkgs-final.fetchFromGitHub {
    owner = "mikebrady";
    repo = "shairport-sync";
    rev = version;
    sha256 = "sha256-0P0AG11h07kgOjGh6kVHEGxFmlo2MUU0mcTF6Wbxt2I=";
  };
})
