{ pkgs, ... }: {
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
