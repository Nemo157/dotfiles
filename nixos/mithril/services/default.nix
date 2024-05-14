{
  imports = [
    ./atuin.nix
    ./grafana.nix
    ./influxdb.nix
    ./nix-serve.nix
    ./nixseparatedebuginfod.nix
    ./samba.nix
    ./telegraf.nix
  ];

  services.upower.enable = true;
}
