{ lib, config, pkgs, ... }: {
  xdg.dataFile."light-mode.d/eww-light.sh" = {
    source = pkgs.writeShellScript "eww-light.sh" ''
      ${lib.getExe pkgs.eww-wayland} update color-scheme=light
    '';
  };

  xdg.dataFile."dark-mode.d/eww-dark.sh" = {
    source = pkgs.writeShellScript "eww-dark.sh" ''
      ${lib.getExe pkgs.eww-wayland} update color-scheme=dark
    '';
  };
}
