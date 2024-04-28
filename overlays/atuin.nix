{ pkgs-final, pkgs-prev, ... }:

pkgs-prev.atuin.overrideAttrs (atuin-final: atuin-prev: rec {
  version = "e15acd773dd9d59a83dd727296ee93687e5b9ace";
  src = pkgs-final.fetchFromGitHub {
    owner = "atuinsh";
    repo = "atuin";
    rev = version;
    sha256 = "sha256-ADHdslBVGPiXk1mO9FVp+ZBD99gFXoUrM2zyxCxFhFE=";
  };
  cargoDeps = atuin-prev.cargoDeps.overrideAttrs {
    name = "atuin-${version}-vendor.tar.gz";
    inherit src;
    outputHash = "sha256-LrwSXPLuQjUaEx3A5dy9oTU997+jcWQs1ovB4niJBS0=";
  };
})
