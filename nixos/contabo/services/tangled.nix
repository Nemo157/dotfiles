{ config, ... }: {
  networking.interfaces.ens18.ipv6.addresses = [
    { # victor.nemo157.com
      address = "2a02:c207:2020:2848:353d:2b74:c8f2:b692";
      prefixLength = 64;
    }
  ];

  services.tangled-knot = {
    enable = true;

    openFirewall = false;

    server = {
      listenAddr = "127.0.0.1:5555";
      owner = "did:plc:f2ghetw5p4uita5aukwd3qol";
      hostname = "victor.nemo157.com";
    };
  };
}
