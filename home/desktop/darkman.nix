{ config, pkgs, lib, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      darkman = (prev.darkman.overrideAttrs {
        # Requires unreleased change to not use non-existing `bash` for scripts
        src = pkgs.fetchgit {
          url = "https://gitlab.com/WhyNotHugo/darkman";
          rev = "df9a5f2a7ad976899bf8f1282a4197a7a632623a";
          sha256 = "sha256-+fGIkTVUP9MVdxOmU45i1+RdK/a6hqPHNvFBq/RHt4U=";
        };
      });
    })
  ];

  home.packages = [
    pkgs.darkman
  ];

  xdg.configFile."darkman/config.yaml".text = ''
    lat: 53.0
    lng: 13.5
    usegeoclue: false
    dbusserver: true
    portal: true
  '';
}
