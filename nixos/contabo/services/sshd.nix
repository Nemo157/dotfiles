{ ts, config, pkgs, lib, ... }: {

  networking.interfaces.ens18.ipv6.addresses = [
    {
      address = "2a02:c207:2020:2848::22";
      prefixLength = 64;
    }
  ];

  services.openssh = rec {
    enable = true;
    ports = [ 59127 ];
    openFirewall = true;
    listenAddresses = [
      { addr = ts.self.ip; port = 59127; }
      { addr = "173.249.29.28"; port = 59127; }
      { addr = "[2a02:c207:2020:2848::22]"; port = 59127; }
    ];
  };

}
