{ stdenv, lib, pkgs }:
let
  mkShim = name: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [ pkgs.nix ];
    text = lib.readFile ./rust-shim.sh;
  };
in
  pkgs.symlinkJoin {
    name = "rust-shim";
    paths = [
      (mkShim "cargo")
      (mkShim "rustc")
    ];
  }
