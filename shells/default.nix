{ pkgs }: {
  rofi-wayland = pkgs.mkShell { inputsFrom = [ pkgs.rofi-wayland-unwrapped ]; };

  rust = pkgs.callPackage ./rust { };
}
