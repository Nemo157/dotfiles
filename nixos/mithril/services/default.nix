{
  imports = [
    ./atuin.nix
    ./avahi.nix
    ./influxdb.nix
    ./nix-serve.nix
    ./nixseparatedebuginfod.nix
    ./openssh.nix
    ./pipewire.nix
    ./samba.nix
    ./tailscale.nix
    ./telegraf.nix
  ];

  services.upower.enable = true;
}
