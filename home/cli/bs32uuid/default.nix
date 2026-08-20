{ pkgs, ... }: {
  home.packages = [
    (pkgs.writers.writePython3Bin "bs32uuid" { } (builtins.readFile ./bs32uuid.py))
  ];
}
