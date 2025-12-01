{ pkgs }:
let
  lib = pkgs.lib;
  mkRustShell = args: pkgs.callPackage ./rust args;
in {
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

  qmk = pkgs.mkShell {
    nativeBuildInputs = [
      pkgs.qmk
      pkgs.annepro2-tools
    ];
  };
}
