{ config, pkgs, lib, ... }: {
  systemd.user.services = {
    sunshine = {
      Unit.Description = pkgs.sunshine.meta.description;
      Service.ExecStart = lib.getExe pkgs.sunshine;
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
