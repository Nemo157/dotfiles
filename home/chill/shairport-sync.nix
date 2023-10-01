{ lib, pkgs, ... }: {
  systemd.user.services.shairport-sync = let
    config = builtins.toFile "shairport-sync.conf" ''
      general = {
        dbus_service_bus = "session";
        mpris_service_bus = "session";
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
