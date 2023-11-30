{ pkgs }:
let
  mkRustShell = pkgs.callPackage ./rust { };
in {
  rofi-wayland = pkgs.mkShell {
    inputsFrom = [ pkgs.rofi-wayland-unwrapped ];
  };

  rust = mkRustShell { };
  rust-unwrapped = mkRustShell { custom = false; };

  docs-rs = mkRustShell {
    extraBuildInputs = [ pkgs.sqlx-cli ];
  };
}
