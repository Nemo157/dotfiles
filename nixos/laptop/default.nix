{
  programs.light.enable = true;

  services = {
    automatic-timezoned.enable = true;

    geoclue2 = {
      enable = true;
      appConfig.darkman = {
        isAllowed = true;
        isSystem = false;
      };
    };
  };
}
