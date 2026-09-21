{ lib, pkgs, ... }: {
  imports = [
    ./monado.nix
    ./vive.nix
    ./bsb.nix
  ];
}
