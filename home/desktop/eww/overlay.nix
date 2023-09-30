{ lib, config, pkgs, pkgs-unstable, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      eww-wayland = pkgs-unstable.eww-wayland.overrideAttrs (final: prev: rec {
        version = "tray-3-dynamic-icons";
        src = pkgs.fetchFromGitHub {
          owner = "ralismark";
          repo = "eww";
          rev = "485dd6263df6123d41d04886a53715b037cf7aaf";
          hash = "sha256-+iu16EVM5dcR5F83EEFjCXVZv1jwPgJq/EqG6M78sAw=";
        };
        cargoDeps = prev.cargoDeps.overrideAttrs (lib.const {
          name = "eww-${version}-vendor.tar.gz";
          inherit src;
          outputHash = "sha256-fUTNlAvhfgqrro+4uKyTwQPtoru9AnBHmy0XcOMUfOI=";
        });
        buildInputs = prev.buildInputs ++ [
          pkgs.libdbusmenu-gtk3
        ];
      });
    })
  ];
}
