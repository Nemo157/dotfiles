{
  imports = [
    ./atuin.nix
    ./grafana.nix
    ./influxdb.nix
    ./nix-serve.nix
    ./samba.nix
    ./telegraf.nix
    ./restic.nix
  ];

  services.upower.enable = true;
}
