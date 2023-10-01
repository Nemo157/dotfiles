{ lib, config, pkgs-unstable, ... }: {
  home.packages = [
    (pkgs-unstable.freetube.overrideAttrs (final: prev: {
      # better support for large watch histories
      src = pkgs-unstable.requireFile {
        name = "freetube_0.19.0-nightly-3500_amd64.AppImage.zip";
        url = "https://github.com/FreeTubeApp/FreeTube/suites/16540961365/artifacts/944882863";
        sha256 = "Omgn9Pbtm+AdpVZIcX4uKSCgVUHH+cmMuzOxZTrmT50=";
      };
      # https://github.com/NixOS/nixpkgs/issues/256401#issuecomment-1734912230
      postFixup = prev.postFixup + ''
        source "${pkgs-unstable.makeWrapper}/nix-support/setup-hook"
        wrapProgram $out/bin/freetube \
          --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--enable-features=UseOzonePlatform --ozone-platform=wayland}}"
      '';
    }))
  ];
}
