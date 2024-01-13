{ pkgs-final, pkgs-prev, ... }:

pkgs-prev.swww.overrideAttrs (swww-final: swww-prev: rec {
  version = "4c4e53437374e4f9b0572df2ae6d7a6232a4719a";
  src = pkgs-final.fetchFromGitHub {
    owner = "Nemo157";
    repo = "swww";
    rev = version;
    sha256 = "sha256-iWG+nURD121f4q5MBiShI+NsviWekRoS9xsbbkdaKAM=";
  };
  cargoDeps = swww-prev.cargoDeps.overrideAttrs {
    name = "swww-${version}-vendor.tar.gz";
    inherit src;
    outputHash = "sha256-AsSBRqJA+Zx1GVPVPdA0DujBQS7w1gWNz35NUUz0pXg=";
  };
})
