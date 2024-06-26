{
  imports = [
    ./battery-events.nix
  ];

  programs.light.enable = true;

  services = {
    automatic-timezoned.enable = true;

    geoclue2 = {
      enable = true;

      # https://github.com/NixOS/nixpkgs/issues/321121
      enableWifi = false;

      appConfig.darkman = {
        isAllowed = true;
        isSystem = false;
      };
    };
  };

  # workaround above issue by manually specifying location
  environment.etc = {
    "geolocation".text = ''
      -41.4
      173.0
      0
      160000
    '';
    "geoclue/conf.d/50-static-source.conf".text = ''
      [static-source]
      enable = true
    '';
  };
}
