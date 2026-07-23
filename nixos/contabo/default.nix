{ name, ts, config, pkgs, lib, ... }: {

  imports = [
    ../personal

    ./fsBefore-override.nix
    ./hardware-configuration.nix
    ./nixos-in-place.nix

    ./postgres-upgrade.nix

    ./services
  ];

  boot.loader.grub.enable = true;

  networking.hostName = "contabo";
  networking.firewall.allowedTCPPorts = [ 80 443 8448 ];
  networking.firewall.allowedUDPPorts = [ 43211 ];

  networking.interfaces.ens18.ipv6.addresses = [
    {
      address = "2a02:c207:2020:2848::1";
      prefixLength = 64;
    }
  ];

  networking.defaultGateway6 = {
    address = "fe80::1";
    interface = "ens18";
  };

  system.stateVersion = "18.03";

  services.atd.enable = true;

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_15;
  };

  services.caddy = {
    enable = true;
    extraConfig = ''
      synapse.nemo157.com {
        log
        bind 2a02:c207:2020:2848:ff76:72a7:c00f:9174 173.249.29.28
        encode gzip zstd
        reverse_proxy /_matrix/* localhost:8008
        reverse_proxy /_synapse/client/* localhost:8008
      }

      filomena.nemo157.com {
        log
        bind 2a02:c207:2020:2848:f93e:4d77:d5ec:7fdb 173.249.29.28
        encode gzip zstd
        reverse_proxy /_matrix/* localhost:8010
      }

      music.nemo157.com {
        log
        bind 173.249.29.28
        encode gzip zstd
        reverse_proxy localhost:4533
      }

      ${name}.${ts.domain} {
        log
        bind ${ts.ips.${name}}
        tls internal

        handle /synapse-admin/* {
          uri strip_prefix /synapse-admin
          root * ${pkgs.synapse-admin}
          file_server { browse }
        }

        reverse_proxy /_matrix/* localhost:8008
        reverse_proxy /_synapse/client/* localhost:8008
        reverse_proxy /_synapse/admin/* localhost:8008
      }

      http://${name}.${ts.domain}:4533 {
        log
        bind ${ts.ips.${name}}
        encode gzip zstd
        reverse_proxy localhost:4533
      }
    '';
    email = "0.contabo.letsencrypt@nemo157.com";
  };

  systemd.services.caddy.serviceConfig.ExecStartPre = lib.mkForce [
    "/bin/sh -c 'sleep 5'" # workaround time taken to bind IP addresses
    ''${config.services.caddy.package}/bin/caddy validate --config ${config.services.caddy.configFile}''
  ];

  users.mutableUsers = false;
}
