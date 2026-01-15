{ config, pkgs, lib, ... }:
let
  portals-conf = pkgs.writeTextDir "share/xdg-desktop-portal/portals/portals.conf" ''
    [preferred]
    default=gnome
    org.freedesktop.impl.portal.Settings=darkman
  '';
  packages = [
    pkgs.xdg-desktop-portal
    pkgs.xdg-desktop-portal-gnome
    pkgs.nautilus # used by portal-gnome for the file chooser
    pkgs.darkman
  ];
  portals = pkgs.symlinkJoin {
    name = "xdg-portals";
    paths = [ portals-conf ] ++ packages;
    pathsToLink = [
      "/share/xdg-desktop-portal/portals"
      "/share/applications"
    ];
  };
in {
  home.sessionVariables = {
    XDG_DESKTOP_PORTAL_DIR = "${portals}/share/xdg-desktop-portal/portals";
  };
  home.packages = packages;

  xdg.configFile."systemd/user/xdg-desktop-portal.service.d/verbose.conf".text = ''
    [Service]
    ExecStart=
    ExecStart=${pkgs.xdg-desktop-portal}/libexec/xdg-desktop-portal -v
  '';

  xdg.configFile."systemd/user/xdg-desktop-portal.service.d/portals.conf".text = ''
    [Service]
    Environment=XDG_DESKTOP_PORTAL_DIR="${portals}/share/xdg-desktop-portal/portals"
  '';
}
