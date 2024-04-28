{
  imports = [
    ./atuin.nix
    ./avahi.nix
    ./grafana.nix
    ./influxdb.nix
    ./nix-serve.nix
    ./nixseparatedebuginfod.nix
    ./pipewire.nix
    ./samba.nix
    ./tailscale.nix
    ./telegraf.nix
  ];

  services.upower.enable = true;
}
