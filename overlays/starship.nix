{ pkgs-final, pkgs-unstable, ... }:

pkgs-unstable.starship.overrideAttrs (starship-final: starship-prev: rec {
  # version adding support for jujutsu
  version = "d9acbbcb9321db668624dbf2dfca23ee5a5d94e7";
  src = pkgs-final.fetchFromGitHub {
    owner = "starship";
    repo = "starship";
    rev = version;
    sha256 = "sha256-fjx0LL+IYyhW9Cro7f9yjgT4gsE/DqA8RHVWW5/plUY=";
  };
  cargoDeps = starship-prev.cargoDeps.overrideAttrs {
    name = "starship-${version}-vendor.tar.gz";
    inherit src;
    outputHash = "sha256-0OANhGh5j2y4Avc7YI8dDZ1emDBDdPixR0R/mqjtrgM=";
  };
})
