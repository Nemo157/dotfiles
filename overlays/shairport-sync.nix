{ pkgs-final, pkgs-prev, ... }:

# contains a fixed pipewire output module
pkgs-prev.shairport-sync.overrideAttrs {
  src = pkgs-final.fetchFromGitHub {
    owner = "mikebrady";
    repo = "shairport-sync";
    rev = "4447b25a05b648b28c002cd6c7d519e793f4434f";
    sha256 = "sha256-5fuGdKHyG9YFTG7NEc5Rs7WNkFEcP+Pj/O+04zTgbxc=";
  };
}
