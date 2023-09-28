{ lib, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      shairport-sync = prev.shairport-sync.overrideAttrs {
        patches = [
          # workaround for https://github.com/mikebrady/shairport-sync/issues/1736
          ./shairport-sync-increase-pipewire-latency.patch
        ];
      };
    })
  ];

  systemd.user.services.shairport-sync = let
    config = builtins.toFile "shairport-sync.conf" ''
      general = {
        drift_tolerance_in_seconds = 0.1;
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
