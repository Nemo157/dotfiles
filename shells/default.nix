{ pkgs }:
let
  lib = pkgs.lib;
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

  wasi = pkgs.mkShell {
    shellHook = ''
      export CARGO_TARGET_WASM32_WASI_RUSTFLAGS="-Lnative=${pkgs.pkgsCross.wasi32.wasilibc}/lib"
      export CARGO_TARGET_WASM32_WASI_RUSTDOCFLAGS="-Lnative=${pkgs.pkgsCross.wasi32.wasilibc}/lib"
      export CARGO_TARGET_WASM32_WASI_RUNNER="${lib.getExe pkgs.wasmtime}"
    '';
  };
}
