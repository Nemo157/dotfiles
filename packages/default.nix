{ pkgs }: {
  gh-poi = pkgs.callPackage ./gh-poi.nix { };

  cargo-dl = pkgs.callPackage ./cargo-dl.nix { };

  cargo-minimal-versions = pkgs.callPackage ./cargo-minimal-versions.nix { };

  sshagmux = pkgs.callPackage ./sshagmux.nix { };
}
