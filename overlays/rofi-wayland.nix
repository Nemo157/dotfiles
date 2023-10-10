{ pkgs-final, pkgs-unstable }:

pkgs-unstable.rofi-wayland-unwrapped.overrideAttrs (final: prev: rec {
  version = prev.version + "-patched";
  patches = [
    # Fix handling multiple groups in xkb layout
    ./rofi-wayland.patch
  ];
})
