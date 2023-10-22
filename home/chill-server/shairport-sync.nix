{ lib, pkgs, ... }: {
  systemd.user.services.shairport-sync = let
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
  in {
    Unit = {
      Description = pkgs.shairport-sync.meta.description;
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.shairport-sync} -c ${config} -v -o pw";
      RuntimeDirectory = "shairport-sync";
    };
  };
}
