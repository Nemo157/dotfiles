{ lib, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      shairport-sync = prev.shairport-sync.overrideAttrs {
        src = pkgs.fetchFromGitHub {
          owner = "mikebrady";
          repo = "shairport-sync";
          rev = "4447b25a05b648b28c002cd6c7d519e793f4434f";
          sha256 = "sha256-5fuGdKHyG9YFTG7NEc5Rs7WNkFEcP+Pj/O+04zTgbxc=";
        };
      };
    })
  ];

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
