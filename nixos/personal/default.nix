{ ts, options, ... }: {
  imports = [
    ./services
    ./users.nix
  ];

  networking.timeServers = [ "contabo.${ts.domain}" ];
}
