{ config, ... }: {
  networking.interfaces.ens18.ipv6.addresses = [
    { # odell.nemo157.com
      address = "2a02:c207:2020:2848:533f:f053:25f3:c8dc";
      prefixLength = 64;
    }
  ];

  age.secrets.pds-environment = {
    file = ./pds-environment.age;
    owner = "pds";
    group = "pds";
  };


  # a.k.a. bluesky/atproto server
  services.pds = {
    enable = true;
    settings = {
      PDS_HOSTNAME = "odell.nemo157.com";
      PDS_PORT = 40906;
    };
    environmentFiles = [
      config.age.secrets.pds-environment.path
    ];
  };
}
