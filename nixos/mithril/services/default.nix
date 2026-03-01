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

  services.wyoming.piper.servers."default" = {
    enable = true;
    voice = "en_US-libritts_r-medium";
    uri = "tcp://127.0.0.1:10200";
  };
}
