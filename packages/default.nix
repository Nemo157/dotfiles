{ pkgs }: {
  gh-poi = pkgs.callPackage ./gh-poi.nix { };

  cargo-dl = pkgs.callPackage ./cargo-dl.nix { };
}
