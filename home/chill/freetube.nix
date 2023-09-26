{ lib, config, pkgs-unstable, ... }: {
  home.packages = [
    (pkgs-unstable.freetube.overrideAttrs {
      src = pkgs-unstable.requireFile {
        name = "freetube_0.19.0-nightly-3500_amd64.AppImage.zip";
        url = "https://github.com/FreeTubeApp/FreeTube/suites/16540961365/artifacts/944882863";
        sha256 = "Omgn9Pbtm+AdpVZIcX4uKSCgVUHH+cmMuzOxZTrmT50=";
      };
    })
  ];
}
