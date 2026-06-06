{ name, ts, config, pkgs, ... }: {
  services.calibre-web = {
    enable = true;
    package = (pkgs.unstable.calibre-web.overridePythonAttrs (old: {
      dependencies = old.dependencies ++ old.optional-dependencies.kobo;
      patches = [
        (pkgs.fetchpatch {
          url = "https://patch-diff.githubusercontent.com/raw/janeczku/calibre-web/pull/2997.patch";
          hash = "sha256-fYqm2K8NWkVeyFQf8zqYLnOJaZLIXXQXB44rNokOa30=";
        })
      ];
    }));
    listen = {
      ip = "10.20.11.21";
      port = 59819;
    };
    options = {
      calibreLibrary = "/home/nemo157/Calibre";
    };
  };

  networking.firewall.interfaces.enp39s0.allowedTCPPorts = [
    config.services.calibre-web.listen.port
  ];
}
