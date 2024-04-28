{ config, pkgs, lib, ... }: {

  networking.interfaces.ens18.ipv6.addresses = [
    { # synapse client -- synapse.nemo157.com
      address = "2a02:c207:2020:2848:ff76:72a7:c00f:9174";
      prefixLength = 64;
    }
    { # synapse federation -- filomena.nemo157.com
      address = "2a02:c207:2020:2848:f93e:4d77:d5ec:7fdb";
      prefixLength = 64;
    }
  ];

  services.matrix-synapse = rec {
    enable = true;
    dataDir = "/var/lib/matrix-synapse";
    settings = {
      server_name = "nemo157.com";
      database.name = "psycopg2";
      experimental_features = {
        spaces_enabled = true;
      };
      listeners = [
        {
          port = 8008;
          tls = false;
          x_forwarded = true;
          resources = [{ names = ["client"]; compress = false; }];
        }
        {
          port = 8010;
          tls = false;
          x_forwarded = true;
          resources = [{ names = ["federation"]; compress = false; }];
        }
      ];
    };
  };

  services.postgresql.enable = true;

}
