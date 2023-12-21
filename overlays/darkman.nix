{ pkgs-final, pkgs-prev, ... }:

# Requires unreleased change to avoid using `bash` for scripts
pkgs-prev.darkman.overrideAttrs rec {
  version = "df9a5f2a7ad976899bf8f1282a4197a7a632623a";
  src = pkgs-final.fetchgit {
    url = "https://gitlab.com/WhyNotHugo/darkman";
    rev = version;
    sha256 = "sha256-+fGIkTVUP9MVdxOmU45i1+RdK/a6hqPHNvFBq/RHt4U=";
  };
}
