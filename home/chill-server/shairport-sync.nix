{ lib, pkgs, ... }: let
    shairport-sync = pkgs.shairport-sync.override {
      enableAirplay2 = false;
      enableAlsa = false;
      enablePulse = false;
      enablePipe = false;
      enableJack = false;
      enableMpris = false;
      enableDbus = false;
      enableMetadata = false;
      enableLibdaemon = false;
    };

    config = builtins.toFile "shairport-sync.conf" ''
      general = {
        ignore_volume_control = "yes";
        dbus_service_bus = "session";
        mpris_service_bus = "session";
      };
      sessioncontrol = {
        session_timeout = 3600;
      };
      diagnostics = {
        statistics = "yes";
      };
    '';

    mk-service = config-text: let
      config = builtins.toFile "shairport-sync.conf" config-text;
    in {
      Unit = {
        Description = pkgs.shairport-sync.meta.description;
      };
      Service = {
        ExecStart = "${lib.getExe shairport-sync} -c ${config} -v -o pw";
        RuntimeDirectory = "shairport-sync";
        Restart = "on-failure";
        RestartSteps = 5;
        RestartMaxDelaySec = 10;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
in {
  systemd.user.services = {
    shairport-sync = mk-service ''
      general = {
        name = "%h";
        dbus_service_bus = "session";
        mpris_service_bus = "session";
        ignore_volume_control = "yes";
      };
    '';

    shairport-sync-2 = mk-service ''
      general = {
        name = "%h2";
        dbus_service_bus = "session";
        mpris_service_bus = "session";
        ignore_volume_control = "yes";
        airplay_device_id_offset = 1;
        port = 5001;
      };
    '';
  };
}
